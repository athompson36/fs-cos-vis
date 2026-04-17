import Foundation

// MARK: - Cue envelope (rise + hold)

enum FogHazeCueEnvelope {
    static func resolveTargetInstanceID(from preset: HazeLearnPreset, patch: DMXPatchDocument) -> UUID? {
        if let id = preset.targetInstanceID, patch.instances.contains(where: { $0.id == id }) {
            return id
        }
        return firstHazerInstance(in: patch)?.id
    }

    static func firstHazerInstance(in patch: DMXPatchDocument) -> FixtureInstance? {
        patch.instances.first { inst in
            guard let p = patch.profile(id: inst.profileID) else { return false }
            return p.channels.contains { $0.role == .hazeOutput }
        }
    }

    static func hazeOutputDMXChannel(patch: DMXPatchDocument, instanceID: UUID) -> Int? {
        guard let inst = patch.instances.first(where: { $0.id == instanceID }),
              let profile = patch.profile(id: inst.profileID),
              let idx = profile.channels.firstIndex(where: { $0.role == .hazeOutput })
        else { return nil }
        let ch = inst.startAddress + idx
        guard ch >= 1, ch <= 512 else { return nil }
        return ch
    }

    /// Rise-only: linear 0…steady over `riseTimeSeconds`, then hold until the cue changes.
    static func merge(
        cueMap: inout [Int: UInt8],
        activeCue: LightingCue?,
        patch: DMXPatchDocument,
        envelopeStartedAt: TimeInterval?,
        now: TimeInterval
    ) {
        guard let cue = activeCue,
              cue.autoApplyHazeEnvelope,
              let preset = cue.hazeLearnPreset,
              let start = envelopeStartedAt,
              let instID = resolveTargetInstanceID(from: preset, patch: patch),
              let dmxCh = hazeOutputDMXChannel(patch: patch, instanceID: instID)
        else { return }
        let elapsed = max(0, now - start)
        let rise = max(0.05, preset.riseTimeSeconds)
        let steady = Float(preset.steadyHazeDMX)
        let t = min(1, Float(elapsed / rise))
        let v = UInt8(min(255, max(0, Int((steady * t).rounded()))))
        cueMap[dmxCh] = v
    }
}

// MARK: - Learn workflow

enum FogHazeLearnError: Error, LocalizedError {
    case cueNotFound
    case hazerNotFound
    case snapshotFailed

    var errorDescription: String? {
        switch self {
        case .cueNotFound: return "Lighting cue not found."
        case .hazerNotFound: return "Hazer fixture not found in patch."
        case .snapshotFailed: return "Could not snapshot DMX patch."
        }
    }
}

@MainActor
enum FogHazeLearnService {
    private static let sampleInterval: UInt64 = 500_000_000
    private static let lumaStableEpsilon = 0.004
    private static let stableSampleCount = 4

    static func brightenNonHazerRig(patch: inout DMXPatchDocument) {
        for i in patch.instances.indices {
            guard let profile = patch.profile(id: patch.instances[i].profileID) else { continue }
            let hasHazeRole = profile.channels.contains { [.hazeOutput, .hazeFan, .hazePump].contains($0.role) }
            for (idx, ch) in profile.channels.enumerated() {
                switch ch.role {
                case .hazeOutput, .hazePump:
                    break
                case .hazeFan:
                    patch.instances[i].setManual(channelIndex: idx, value: 180)
                case .strobe:
                    patch.instances[i].setManual(channelIndex: idx, value: 0)
                case .intensity, .red, .green, .blue, .white, .amber, .uv:
                    patch.instances[i].setManual(channelIndex: idx, value: 255)
                case .pan, .tilt:
                    patch.instances[i].setManual(channelIndex: idx, value: 128)
                case .generic:
                    if !hasHazeRole {
                        patch.instances[i].setManual(channelIndex: idx, value: 255)
                    }
                }
            }
        }
    }

    private static func profileHasHazeOutput(_ profile: FixtureProfile) -> Bool {
        profile.channels.contains { $0.role == .hazeOutput }
    }

    private static func channelIndex(for role: FixtureChannelRole, profile: FixtureProfile) -> Int? {
        profile.channels.firstIndex { $0.role == role }
    }

    private static func setHazerOutputPump(
        patch: inout DMXPatchDocument,
        instanceID: UUID,
        output: UInt8,
        pump: UInt8
    ) {
        guard let idx = patch.instances.firstIndex(where: { $0.id == instanceID }),
              let profile = patch.profile(id: patch.instances[idx].profileID)
        else { return }
        if let oi = channelIndex(for: .hazeOutput, profile: profile) {
            patch.instances[idx].setManual(channelIndex: oi, value: output)
        }
        if let pi = channelIndex(for: .hazePump, profile: profile) {
            patch.instances[idx].setManual(channelIndex: pi, value: pump)
        }
    }

    private static func averageLuma(webcam: WebcamCaptureService, samples: Int) async throws -> Double {
        var sum = 0.0
        var n = 0
        for _ in 0 ..< samples {
            try Task.checkCancellation()
            sum += webcam.latestSampleLuma
            n += 1
            try await Task.sleep(nanoseconds: sampleInterval)
        }
        return n > 0 ? sum / Double(n) : 0
    }

    private static func upsertChannel(_ cue: inout LightingCue, channel: Int, value: UInt8) {
        if let i = cue.channelValues.firstIndex(where: { $0.channel == channel }) {
            cue.channelValues[i].value = value
        } else {
            cue.channelValues.append(ChannelValue(channel: channel, value: value))
        }
    }

    private static func syncHazerChannelsToCue(
        cue: inout LightingCue,
        patch: DMXPatchDocument,
        instanceID: UUID,
        steadyHazeOutput: UInt8
    ) {
        guard let inst = patch.instances.first(where: { $0.id == instanceID }),
              let profile = patch.profile(id: inst.profileID)
        else { return }
        for (idx, def) in profile.channels.enumerated() where [.hazeOutput, .hazeFan, .hazePump].contains(def.role) {
            let dmx = inst.startAddress + idx
            guard dmx >= 1, dmx <= 512 else { continue }
            let v: UInt8 = def.role == .hazeOutput ? steadyHazeOutput : inst.manual(forChannelIndex: idx)
            upsertChannel(&cue, channel: dmx, value: v)
        }
    }

    /// Strobe on non-hazer fixtures with a strobe role; otherwise brief dimmer flash on first intensity fixture without hazer output.
    private static func strobeConfirm(app: AppModel, patch: inout DMXPatchDocument) async throws {
        var strobeSlots: [(instanceIndex: Int, channelIndex: Int)] = []
        for (ii, inst) in patch.instances.enumerated() {
            guard let profile = patch.profile(id: inst.profileID), !profileHasHazeOutput(profile) else { continue }
            for (ci, def) in profile.channels.enumerated() where def.role == .strobe {
                strobeSlots.append((ii, ci))
            }
        }
        if !strobeSlots.isEmpty {
            for pulse in 0 ..< 3 {
                try Task.checkCancellation()
                let on = pulse % 2 == 0
                for s in strobeSlots {
                    patch.instances[s.instanceIndex].setManual(
                        channelIndex: s.channelIndex,
                        value: on ? 255 : 0
                    )
                }
                app.applyDMXPatchDocument(patch)
                try await Task.sleep(nanoseconds: 90_000_000)
            }
            return
        }
        var dimmerFlash: (Int, Int)?
        outer: for (ii, inst) in patch.instances.enumerated() {
            guard let profile = patch.profile(id: inst.profileID), !profileHasHazeOutput(profile) else { continue }
            for (ci, def) in profile.channels.enumerated() where def.role == .intensity {
                dimmerFlash = (ii, ci)
                break outer
            }
        }
        guard let slot = dimmerFlash else { return }
        for pair in [(UInt8(0), 90_000_000), (UInt8(255), 90_000_000), (UInt8(0), 90_000_000)] as [(UInt8, UInt64)] {
            try Task.checkCancellation()
            patch.instances[slot.0].setManual(channelIndex: slot.1, value: pair.0)
            app.applyDMXPatchDocument(patch)
            try await Task.sleep(nanoseconds: pair.1)
        }
    }

    static func run(
        app: AppModel,
        webcam: WebcamCaptureService,
        targetCueID: UUID,
        hazerInstanceID: UUID,
        progress: @escaping (String) -> Void
    ) async throws {
        let snapshotData: Data
        do {
            snapshotData = try JSONEncoder().encode(app.dmxPatchDocument)
        } catch {
            throw FogHazeLearnError.snapshotFailed
        }

        progress("Starting camera…")
        try await webcam.startIfAuthorized()
        defer { webcam.stop() }

        guard app.lightingCueDocument.cues.contains(where: { $0.id == targetCueID }) else {
            throw FogHazeLearnError.cueNotFound
        }
        guard patchContainsHazer(app.dmxPatchDocument, instanceID: hazerInstanceID) else {
            throw FogHazeLearnError.hazerNotFound
        }

        let baselinePreBright = try await averageLuma(webcam: webcam, samples: 4)
        progress("Brightening rig (non-hazer channels)…")
        var brightPatch = try JSONDecoder().decode(DMXPatchDocument.self, from: snapshotData)
        brightenNonHazerRig(patch: &brightPatch)
        app.applyDMXPatchDocument(brightPatch)
        try await Task.sleep(nanoseconds: 600_000_000)
        let baselineBright = try await averageLuma(webcam: webcam, samples: 6)

        progress("Rise: ramping hazer output (watch luma)…")
        setHazerOutputPump(patch: &brightPatch, instanceID: hazerInstanceID, output: 0, pump: 200)
        app.applyDMXPatchDocument(brightPatch)

        var outputLevel: UInt8 = 0
        let riseStart = CFAbsoluteTimeGetCurrent()
        var lastLumas: [Double] = []
        var peakLuma = baselineBright
        var steadyOutput: UInt8 = 0
        let riseTimeout: CFAbsoluteTime = 120

        riseLoop: while outputLevel < 255 {
            try Task.checkCancellation()
            if CFAbsoluteTimeGetCurrent() - riseStart > riseTimeout { break }
            setHazerOutputPump(patch: &brightPatch, instanceID: hazerInstanceID, output: outputLevel, pump: 200)
            app.applyDMXPatchDocument(brightPatch)
            try await Task.sleep(nanoseconds: sampleInterval)
            let lu = webcam.latestSampleLuma
            peakLuma = max(peakLuma, lu)
            lastLumas.append(lu)
            if lastLumas.count > stableSampleCount { lastLumas.removeFirst() }
            if outputLevel >= 16,
               lastLumas.count == stableSampleCount,
               let maxL = lastLumas.max(),
               let minL = lastLumas.min(),
               maxL - minL < lumaStableEpsilon,
               lu > baselineBright + 0.012
            {
                steadyOutput = outputLevel
                break riseLoop
            }
            outputLevel = min(255, outputLevel &+ 8)
        }
        if steadyOutput == 0 { steadyOutput = outputLevel }

        let riseElapsed = max(0.05, CFAbsoluteTimeGetCurrent() - riseStart)

        progress("Dissipation: output off, sampling decay…")
        setHazerOutputPump(patch: &brightPatch, instanceID: hazerInstanceID, output: 0, pump: 0)
        app.applyDMXPatchDocument(brightPatch)
        let decayStart = CFAbsoluteTimeGetCurrent()
        let excessPeak = max(1e-6, peakLuma - baselineBright)
        let halfTarget = baselineBright + 0.5 * excessPeak
        var halfTime: CFAbsoluteTime?
        let decayDeadline = decayStart + 60
        while CFAbsoluteTimeGetCurrent() < decayDeadline {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: sampleInterval)
            let lu = webcam.latestSampleLuma
            if halfTime == nil, lu <= halfTarget {
                halfTime = CFAbsoluteTimeGetCurrent() - decayStart
            }
            if lu <= baselineBright + 0.025 {
                break
            }
        }
        let dissipationHalfLife = max(0.5, halfTime ?? (CFAbsoluteTimeGetCurrent() - decayStart) * 0.6)

        progress("Strobe confirm…")
        try await strobeConfirm(app: app, patch: &brightPatch)
        try await Task.sleep(nanoseconds: 200_000_000)

        progress("Restoring patch…")
        let restored = try JSONDecoder().decode(DMXPatchDocument.self, from: snapshotData)
        app.applyDMXPatchDocument(restored)

        let preset = HazeLearnPreset(
            steadyHazeDMX: steadyOutput,
            riseTimeSeconds: riseElapsed,
            dissipationHalfLifeSeconds: dissipationHalfLife,
            learnedAt: Date(),
            cameraBaselineLuma: baselinePreBright,
            cameraPeakLuma: peakLuma,
            targetInstanceID: hazerInstanceID
        )

        var cueDoc = app.lightingCueDocument
        guard let ci = cueDoc.cues.firstIndex(where: { $0.id == targetCueID }) else {
            throw FogHazeLearnError.cueNotFound
        }
        cueDoc.cues[ci].hazeLearnPreset = preset
        syncHazerChannelsToCue(
            cue: &cueDoc.cues[ci],
            patch: restored,
            instanceID: hazerInstanceID,
            steadyHazeOutput: steadyOutput
        )
        app.applyLightingCueDocument(cueDoc)
        progress("Done — preset saved on cue \"\(cueDoc.cues[ci].name)\".")
    }

    private static func patchContainsHazer(_ patch: DMXPatchDocument, instanceID: UUID) -> Bool {
        guard let inst = patch.instances.first(where: { $0.id == instanceID }),
              let profile = patch.profile(id: inst.profileID)
        else { return false }
        return profile.channels.contains { $0.role == .hazeOutput }
    }
}
