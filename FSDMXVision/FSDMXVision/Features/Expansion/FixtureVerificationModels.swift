import Foundation

enum FixtureVerificationStatus: String, Codable, CaseIterable, Sendable {
    case pass
    case fail
    case warn
}

struct FixtureVerificationCategoryResult: Codable, Equatable, Sendable {
    var status: FixtureVerificationStatus
    var note: String
}

struct FixtureVerificationFixtureResult: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var fixtureID: UUID
    var fixtureName: String
    var fixtureIndex: Int
    var startAddress: Int
    var channelSpan: Int
    var expectedPlacement: StagePlacement?
    var observedLumaDelta: Double
    var patching: FixtureVerificationCategoryResult
    var quantity: FixtureVerificationCategoryResult
    var layout: FixtureVerificationCategoryResult
    var orientation: FixtureVerificationCategoryResult

    init(
        id: UUID = UUID(),
        fixtureID: UUID,
        fixtureName: String,
        fixtureIndex: Int,
        startAddress: Int,
        channelSpan: Int,
        expectedPlacement: StagePlacement?,
        observedLumaDelta: Double,
        patching: FixtureVerificationCategoryResult,
        quantity: FixtureVerificationCategoryResult,
        layout: FixtureVerificationCategoryResult,
        orientation: FixtureVerificationCategoryResult
    ) {
        self.id = id
        self.fixtureID = fixtureID
        self.fixtureName = fixtureName
        self.fixtureIndex = fixtureIndex
        self.startAddress = startAddress
        self.channelSpan = channelSpan
        self.expectedPlacement = expectedPlacement
        self.observedLumaDelta = observedLumaDelta
        self.patching = patching
        self.quantity = quantity
        self.layout = layout
        self.orientation = orientation
    }
}

struct FixtureVerificationDocument: Codable, Equatable, Sendable {
    static let currentVersion = 1

    var version: Int
    var updatedAt: Date
    var fixtureCountExpected: Int
    var fixtureCountScanned: Int
    var notes: String
    var fixtures: [FixtureVerificationFixtureResult]

    init(
        version: Int = currentVersion,
        updatedAt: Date = Date(),
        fixtureCountExpected: Int,
        fixtureCountScanned: Int,
        notes: String = "",
        fixtures: [FixtureVerificationFixtureResult]
    ) {
        self.version = version
        self.updatedAt = updatedAt
        self.fixtureCountExpected = fixtureCountExpected
        self.fixtureCountScanned = fixtureCountScanned
        self.notes = notes
        self.fixtures = fixtures
    }
}

enum FixtureVerificationRunStatus: Equatable, Sendable {
    case completed
    case cancelled
    case pausedPrimaryCameraDisconnected
}

enum FixtureVerificationSeverityFilter: String, CaseIterable, Sendable {
    case all
    case fail
    case warn
    case pass
}

enum FixtureVerificationEvaluator {
    static let patchingThreshold = 0.03

    static func patchingResult(lumaDelta: Double, threshold: Double) -> FixtureVerificationCategoryResult {
        if lumaDelta >= threshold {
            return FixtureVerificationCategoryResult(status: .pass, note: "Observed DMX response (\(String(format: "%.3f", lumaDelta))).")
        }
        return FixtureVerificationCategoryResult(status: .fail, note: "No clear response (\(String(format: "%.3f", lumaDelta))).")
    }

    static func quantityResult(expected: Int, scanned: Int) -> FixtureVerificationCategoryResult {
        if expected == scanned {
            return FixtureVerificationCategoryResult(status: .pass, note: "Scanned \(scanned)/\(expected) fixtures.")
        }
        if scanned == 0 {
            return FixtureVerificationCategoryResult(status: .fail, note: "No fixtures scanned.")
        }
        return FixtureVerificationCategoryResult(status: .warn, note: "Scanned \(scanned)/\(expected) fixtures.")
    }

    static func layoutResult(expectedPlacement: StagePlacement?) -> FixtureVerificationCategoryResult {
        guard let expectedPlacement else {
            return FixtureVerificationCategoryResult(status: .warn, note: "No venue-map placement; set position in Stage Layout.")
        }
        let inRange = (0 ... 1).contains(expectedPlacement.x) && (0 ... 1).contains(expectedPlacement.y)
        if inRange {
            return FixtureVerificationCategoryResult(status: .pass, note: "Mapped to venue layout (\(String(format: "%.2f", expectedPlacement.x)), \(String(format: "%.2f", expectedPlacement.y))).")
        }
        return FixtureVerificationCategoryResult(status: .fail, note: "Placement out of normalized bounds.")
    }

    static func orientationResult(profile: FixtureProfile, placement: StagePlacement?) -> FixtureVerificationCategoryResult {
        guard let placement else {
            return FixtureVerificationCategoryResult(status: .warn, note: "No orientation target in venue map.")
        }
        let hasAimChannels = profile.channels.contains { $0.role == .pan || $0.role == .tilt }
        if hasAimChannels {
            return FixtureVerificationCategoryResult(status: .pass, note: "Orientation target set to \(Int(placement.rotation))°.")
        }
        return FixtureVerificationCategoryResult(status: .warn, note: "Fixture has no pan/tilt channels; orientation is static.")
    }

    static func phaseText(status: FixtureVerificationRunStatus, scanned: Int, expected: Int) -> String {
        switch status {
        case .completed:
            return "Fixture verification complete (\(scanned)/\(expected))."
        case .cancelled:
            return "Fixture verification cancelled (\(scanned)/\(expected))."
        case .pausedPrimaryCameraDisconnected:
            return "Primary camera disconnected. Reconnect/reposition camera, then resume scan (\(scanned)/\(expected))."
        }
    }

    static func notesText(status: FixtureVerificationRunStatus, usedSecondary: Bool) -> String {
        switch status {
        case .completed:
            return "Assisted fixture verification using DMX one-fixture-at-a-time luma probing\(usedSecondary ? ", primary + secondary angled camera" : ", primary camera only")."
        case .cancelled:
            return "Fixture verification cancelled before finishing\(usedSecondary ? " (dual-camera attempt active)." : " (primary camera only).")"
        case .pausedPrimaryCameraDisconnected:
            return "Fixture verification paused: primary camera disconnected mid-scan; reconnect camera and resume."
        }
    }

    static func severity(for fixture: FixtureVerificationFixtureResult) -> FixtureVerificationStatus {
        let statuses = [fixture.patching.status, fixture.quantity.status, fixture.layout.status, fixture.orientation.status]
        if statuses.contains(.fail) { return .fail }
        if statuses.contains(.warn) { return .warn }
        return .pass
    }

    static func matches(filter: FixtureVerificationSeverityFilter, fixture: FixtureVerificationFixtureResult) -> Bool {
        switch filter {
        case .all:
            return true
        case .fail:
            return severity(for: fixture) == .fail
        case .warn:
            return severity(for: fixture) == .warn
        case .pass:
            return severity(for: fixture) == .pass
        }
    }

    static func exposureHint(
        primaryBaseline: Double,
        primaryLit: Double,
        secondaryBaseline: Double?,
        secondaryLit: Double?,
        observedDelta: Double
    ) -> String? {
        let baselineValues = [primaryBaseline, secondaryBaseline].compactMap { $0 }
        let litValues = [primaryLit, secondaryLit].compactMap { $0 }
        let minBaseline = baselineValues.min() ?? primaryBaseline
        let maxLit = litValues.max() ?? primaryLit

        if maxLit >= 0.97 {
            return "Overexposed camera feed; lower exposure or reduce ambient brightness."
        }
        if minBaseline <= 0.05 && observedDelta < patchingThreshold {
            return "Low-light feed; increase front light or camera gain for reliable verification."
        }
        if observedDelta < patchingThreshold,
           observedDelta >= patchingThreshold * 0.5,
           maxLit < 0.97,
           minBaseline > 0.05
        {
            return "Weak contrast on camera; adjust angle, zoom, or lock exposure if response stays borderline."
        }
        return nil
    }

    /// Maps category status to a 0…1 contribution for confidence blending.
    static func statusContribution(_ status: FixtureVerificationStatus) -> Double {
        switch status {
        case .pass: return 1.0
        case .warn: return 0.55
        case .fail: return 0.15
        }
    }

    /// Normalizes observed luma step strength (rolls off above ~0.12).
    static func patchingSignalQuality01(delta: Double) -> Double {
        min(1.0, max(0, delta) / 0.12)
    }

    /// Blended 0…1 score from patching signal, quantity, layout, and orientation (per-fixture).
    static func confidence01(for fixture: FixtureVerificationFixtureResult) -> Double {
        let sig = patchingSignalQuality01(delta: fixture.observedLumaDelta)
        let patchStat = statusContribution(fixture.patching.status)
        let patchingBlend = sig * 0.55 + patchStat * 0.45
        let q = statusContribution(fixture.quantity.status)
        let l = statusContribution(fixture.layout.status)
        let o = statusContribution(fixture.orientation.status)
        let raw = patchingBlend * 0.42 + q * 0.23 + l * 0.20 + o * 0.15
        return max(0, min(1, raw))
    }

    static func confidencePercent(for fixture: FixtureVerificationFixtureResult) -> Int {
        Int((confidence01(for: fixture) * 100).rounded())
    }

    static func averageConfidence01(for report: FixtureVerificationDocument) -> Double? {
        guard !report.fixtures.isEmpty else { return nil }
        let sum = report.fixtures.reduce(0.0) { $0 + confidence01(for: $1) }
        return sum / Double(report.fixtures.count)
    }

    static func averageConfidencePercent(for report: FixtureVerificationDocument) -> Int? {
        guard let avg = averageConfidence01(for: report) else { return nil }
        return Int((avg * 100).rounded())
    }
}
