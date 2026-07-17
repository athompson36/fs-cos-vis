import Metal
import XCTest
@testable import FSDMXVision

@MainActor
final class AppModelTests: XCTestCase {
    func testDefaults() {
        let model = AppModel()
        XCTAssertEqual(model.bpm, 0)
        XCTAssertEqual(model.beatConfidence, 0)
        XCTAssertFalse(model.selectedAudioDeviceName.isEmpty)
        XCTAssertNotNil(model.selectedSceneID)
        if MTLCreateSystemDefaultDevice() != nil {
            XCTAssertNotNil(model.metalRenderer, "Expected Metal renderer when a GPU device exists")
        }
    }

    func testRemoteLayerCommands_updateCurrentSceneEdit() {
        let model = AppModel()
        let id = model.sceneManager.scenes[model.sceneManager.currentIndex].id
        model.applyRemoteCommand(RemoteControlCommand(type: "SetFractalExplore", fractalExplore: 0.66))
        model.applyRemoteCommand(RemoteControlCommand(type: "SetZoomEffectType", index: 2))
        model.applyRemoteCommand(RemoteControlCommand(type: "SetSpectrumWarpAmount", spectrumWarpAmount: 0.44))
        model.applyRemoteCommand(RemoteControlCommand(type: "SetFractalGeometryIndex", index: 5))
        XCTAssertEqual(model.sceneEditStates[id]?.layer.fractalExplore ?? 0, 0.66, accuracy: 0.01)
        XCTAssertEqual(model.sceneEditStates[id]?.layer.zoomEffectType ?? -1, 2, accuracy: 0.01)
        XCTAssertEqual(model.sceneEditStates[id]?.layer.spectrumWarpAmount ?? 0, 0.44, accuracy: 0.01)
        XCTAssertEqual(model.sceneEditStates[id]?.layer.fractalGeometryIndex ?? 0, 5, accuracy: 0.01)
    }

    func testMakeWebStateSnapshot_includesLightingCueNames() throws {
        let model = AppModel()
        var doc = LightingCueDocument(version: 1, cues: [], activeCueIndex: nil)
        doc.cues = [
            LightingCue(name: "Wash", channelValues: []),
            LightingCue(name: "Spots", channelValues: []),
        ]
        doc.activeCueIndex = 1
        model.applyLightingCueDocument(doc)
        let data = model.makeWebStateSnapshotData()
        let dto = try JSONDecoder().decode(WebControlStateDTO.self, from: data)
        XCTAssertEqual(dto.lightingCueNames, ["Wash", "Spots"])
        XCTAssertEqual(dto.lightingActiveCueIndex, 1)
        XCTAssertEqual(dto.lightingActiveCueName, "Spots")
        XCTAssertEqual(dto.lightingCueCount, 2)
        XCTAssertEqual(dto.liveOutputRecordingSource, model.liveOutputRecordingSource.rawValue)
        XCTAssertEqual(dto.liveOutputRecordingQualityPreset, model.liveOutputRecordingQualityPreset.rawValue)
        XCTAssertEqual(dto.liveOutputRecording, model.isLiveOutputRecording)
        let perf = model.dmxPerformanceDiagnostics()
        guard let dp = dto.dmxPerformance else {
            XCTFail("expected dmxPerformance in web state")
            return
        }
        XCTAssertEqual(dp.frameCount, perf.frameCount)
        XCTAssertEqual(dp.avgTotalMS, perf.avgTotalMS, accuracy: 0.000_1)
        XCTAssertEqual(dp.maxTotalMS, perf.maxTotalMS, accuracy: 0.000_1)
        XCTAssertEqual(dp.exactMedianTotalMS, perf.exactMedianTotalMS)
        XCTAssertEqual(dp.exactP95TotalMS, perf.exactP95TotalMS)
    }

    func testMakeWebStateSnapshot_includesInboundDMXFields() throws {
        let model = AppModel()
        var rs = model.remoteSettings
        rs.dmxInboundEnabled = true
        rs.dmxInboundMode = "sacn"
        rs.dmxInboundUniverse = 2
        rs.dmxInboundUniverseCount = 4
        rs.dmxInboundMergeMode = "lpt"
        rs.dmxInboundOpenDMXEnabled = true
        rs.dmxInboundOpenDMXPath = "/dev/cu.inbound-test"
        model.remoteSettings = rs
        let data = model.makeWebStateSnapshotData()
        let dto = try JSONDecoder().decode(WebControlStateDTO.self, from: data)
        XCTAssertEqual(dto.dmxInboundEnabled, true)
        XCTAssertEqual(dto.dmxInboundMode, "sacn")
        XCTAssertEqual(dto.dmxInboundUniverse, 2)
        XCTAssertEqual(dto.dmxInboundUniverseCount, 4)
        XCTAssertEqual(dto.dmxInboundMergeMode, "lpt")
        XCTAssertEqual(dto.dmxInboundOpenDMXEnabled, true)
        XCTAssertEqual(dto.dmxInboundOpenDMXPath, "/dev/cu.inbound-test")
        XCTAssertFalse(dto.dmxInboundStatus?.isEmpty ?? true)
        let tel = try XCTUnwrap(dto.dmxInboundTelemetry)
        XCTAssertEqual(tel.networkListenerRunning, false)
        XCTAssertEqual(tel.openDMXSerialRunning, false)
    }

    func testWebControlStateDTO_decodeStripsInboundKeys_toNilOptionals() throws {
        let model = AppModel()
        let full = model.makeWebStateSnapshotData()
        var root = try JSONSerialization.jsonObject(with: full) as! [String: Any]
        for k in [
            "dmxInboundEnabled", "dmxInboundMode", "dmxInboundUniverse", "dmxInboundUniverseCount",
            "dmxInboundMergeMode", "dmxInboundOpenDMXEnabled", "dmxInboundOpenDMXPath",
            "dmxInboundStatus", "dmxInboundTelemetry",
        ] {
            root.removeValue(forKey: k)
        }
        let legacy = try JSONSerialization.data(withJSONObject: root)
        let dto = try JSONDecoder().decode(WebControlStateDTO.self, from: legacy)
        XCTAssertNil(dto.dmxInboundEnabled)
        XCTAssertNil(dto.dmxInboundTelemetry)
        XCTAssertNil(dto.dmxInboundStatus)
    }

    func testResolvedOverlayText_usesActiveCueBookmarkMetadata() {
        let model = AppModel()
        let cueID = UUID(uuidString: "00000000-0000-0000-0000-000000000301")!
        let cue = LightingCue(id: cueID, name: "Verse", fadeSeconds: 1, channelValues: [])
        let cueDoc = LightingCueDocument(
            version: 1,
            cues: [cue],
            activeCueIndex: 0,
            bookmarkedCueIds: [cueID],
            bookmarkMetadataByCueID: [cueID.uuidString: ["song_title": "Midnight City"]]
        )
        model.applyLightingCueDocument(cueDoc)

        let layer = OverlayCardTextLayer(text: "Fallback", metadataKey: "song_title")
        XCTAssertEqual(model.resolvedOverlayText(for: layer), "Midnight City")
    }

    func testOverlayElementTimeout_hidesAfterElapsedTime() {
        let model = AppModel()
        let shapeID = UUID(uuidString: "00000000-0000-0000-0000-000000000302")!
        let overlayDoc = OverlayCardDocument(
            version: 1,
            name: "Card",
            shapes: [OverlayCardShape(id: shapeID, kind: .rect, timeoutSeconds: 1.5)],
            texts: []
        )
        model.applyOverlayCardDocument(overlayDoc)
        XCTAssertTrue(model.shouldRenderOverlayElement(id: shapeID, timeoutSeconds: 1.5))

        model.resetOverlayElementTimers(now: Date(timeIntervalSinceNow: -2.0))
        XCTAssertFalse(model.shouldRenderOverlayElement(id: shapeID, timeoutSeconds: 1.5))
        XCTAssertTrue(model.shouldRenderOverlayElement(id: shapeID, timeoutSeconds: nil))
    }

    func testOverlayMetadataAndTimeout_resetsOnCueTransition() {
        let model = AppModel()
        let cueAID = UUID(uuidString: "00000000-0000-0000-0000-0000000003A1")!
        let cueBID = UUID(uuidString: "00000000-0000-0000-0000-0000000003B2")!
        let cueDoc = LightingCueDocument(
            version: 1,
            cues: [
                LightingCue(id: cueAID, name: "Cue A", fadeSeconds: 1, channelValues: []),
                LightingCue(id: cueBID, name: "Cue B", fadeSeconds: 1, channelValues: []),
            ],
            activeCueIndex: 0,
            bookmarkedCueIds: [cueAID, cueBID],
            bookmarkMetadataByCueID: [
                cueAID.uuidString: ["song_title": "Song A"],
                cueBID.uuidString: ["song_title": "Song B"],
            ]
        )
        model.applyLightingCueDocument(cueDoc)

        let textID = UUID(uuidString: "00000000-0000-0000-0000-0000000003C3")!
        let textLayer = OverlayCardTextLayer(id: textID, text: "Fallback", metadataKey: "song_title", timeoutSeconds: 1.0)
        model.applyOverlayCardDocument(
            OverlayCardDocument(version: 1, name: "Now Playing", shapes: [], texts: [textLayer])
        )

        XCTAssertEqual(model.resolvedOverlayText(for: textLayer), "Song A")
        XCTAssertTrue(model.shouldRenderOverlayElement(id: textID, timeoutSeconds: 1.0))

        model.resetOverlayElementTimers(now: Date(timeIntervalSinceNow: -2.0))
        XCTAssertFalse(model.shouldRenderOverlayElement(id: textID, timeoutSeconds: 1.0))

        model.setActiveLightingCueIndex(1)
        XCTAssertEqual(model.resolvedOverlayText(for: textLayer), "Song B")
        XCTAssertTrue(model.shouldRenderOverlayElement(id: textID, timeoutSeconds: 1.0))
    }

    func testRecallVisualScene_selectsTargetAndStartsTransition() throws {
        let model = AppModel()
        let originalScenes = model.sceneManager.scenes
        let originalIndex = model.sceneManager.currentIndex
        defer {
            model.sceneManager.scenes = originalScenes
            model.sceneManager.currentIndex = originalIndex
            model.syncRendererFromScene()
            try? model.persistScenes()
        }
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000401")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000402")!
        model.sceneManager.scenes = [
            VisualizationScene(id: firstID, name: "First", fractalMode: "julia", liquidLightEnabled: true),
            VisualizationScene(id: secondID, name: "Second", fractalMode: "mandelbrot", liquidLightEnabled: false),
        ]
        model.sceneManager.currentIndex = 0
        model.syncRendererFromScene()

        try model.recallVisualScene(id: secondID)

        XCTAssertEqual(model.sceneManager.currentIndex, 1)
        XCTAssertEqual(model.activeVisualSceneID(), secondID)
        XCTAssertEqual(
            model.transitionState,
            .transitioning(fromSceneID: firstID, toSceneID: secondID, progress: 0)
        )
    }

    func testSelectPalette_updatesSelectedPaletteID() throws {
        let model = AppModel()
        let paletteID = UUID(uuidString: "00000000-0000-0000-0000-000000000403")!
        model.palettes = [
            ThemePalette(
                id: paletteID,
                name: "Show Director",
                primaryHex: "#111111",
                secondaryHex: "#222222",
                accentHex: "#333333",
                glowHex: "#444444"
            ),
        ]

        try model.selectPalette(id: paletteID)

        XCTAssertEqual(model.selectedPaletteID, paletteID)
        XCTAssertEqual(model.activePaletteID(), paletteID)
    }

    func testRecallLightingCue_resolvesUUIDAndUpdatesActiveIndex() throws {
        let model = AppModel()
        let originalDocument = model.lightingCueDocument
        defer { model.applyLightingCueDocument(originalDocument) }
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000404")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000405")!
        model.applyLightingCueDocument(
            LightingCueDocument(
                version: 1,
                cues: [
                    LightingCue(id: firstID, name: "First", fadeSeconds: 0, channelValues: []),
                    LightingCue(id: secondID, name: "Second", fadeSeconds: 1.25, channelValues: []),
                ],
                activeCueIndex: 0
            )
        )

        try model.recallLightingCue(id: secondID)

        XCTAssertEqual(model.lightingCueDocument.activeCueIndex, 1)
        XCTAssertEqual(model.activeLightingCueID(), secondID)
        XCTAssertEqual(model.lightingCueFadeSeconds(id: secondID), 1.25)
    }

    func testEndpointControls_throwTypedErrorsForMissingTargets() {
        let model = AppModel()
        let missingID = UUID(uuidString: "00000000-0000-0000-0000-000000000406")!

        XCTAssertThrowsError(try model.recallVisualScene(id: missingID)) { error in
            XCTAssertEqual(
                error as? ShowDirectorEndpointControlError,
                .targetNotFound(endpoint: .visuals, id: missingID)
            )
        }
        XCTAssertThrowsError(try model.selectPalette(id: missingID)) { error in
            XCTAssertEqual(
                error as? ShowDirectorEndpointControlError,
                .targetNotFound(endpoint: .palette, id: missingID)
            )
        }
        XCTAssertThrowsError(try model.recallLightingCue(id: missingID)) { error in
            XCTAssertEqual(
                error as? ShowDirectorEndpointControlError,
                .targetNotFound(endpoint: .lighting, id: missingID)
            )
        }
    }

    func testSaveShowProject_createsArtifactsAndBackupOnResave() throws {
        let model = AppModel()
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("FSDMXVisionTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        let projectFolder = tempRoot.appendingPathComponent("MyShow", isDirectory: true)

        try model.saveShowProject(to: projectFolder)
        let artifactsFolder = projectFolder.appendingPathComponent("Artifacts", isDirectory: true)
        let configSnapshot = artifactsFolder.appendingPathComponent("config_snapshot.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: configSnapshot.path))

        try model.saveShowProject(to: projectFolder)
        let backupsFolder = projectFolder.appendingPathComponent("Backups", isDirectory: true)
        let backups = try FileManager.default.contentsOfDirectory(atPath: backupsFolder.path)
        XCTAssertFalse(backups.isEmpty)
    }

    func testStartLiveOutputRecording_withoutAvailableWindow_setsStatus() {
        let model = AppModel()
        model.liveOutputRecordingSource = .externalOutput
        model.startLiveOutputRecording(preferredMainWindowNumber: nil)
        XCTAssertFalse(model.isLiveOutputRecording)
        XCTAssertTrue(model.liveOutputRecordingStatus.contains("unavailable"))
    }

    func testRecordingRemoteCommands_updateSourceAndQuality() {
        let model = AppModel()
        model.applyRemoteCommand(RemoteControlCommand(type: "SetLiveOutputRecordingSource", source: "externalOutput"))
        model.applyRemoteCommand(RemoteControlCommand(type: "SetLiveOutputRecordingQualityPreset", source: "archival"))
        XCTAssertEqual(model.liveOutputRecordingSource, .externalOutput)
        XCTAssertEqual(model.liveOutputRecordingQualityPreset, .archival)
    }

    func testSetupWizard_completionAndReset() {
        let model = AppModel()
        model.resetSetupWizard()
        XCTAssertFalse(model.remoteSettings.setupWizardCompleted)
        model.markSetupWizardStep("audio", skipped: true)
        XCTAssertTrue(model.remoteSettings.setupWizardSkippedStepIDs.contains("audio"))
        model.completeSetupWizard()
        XCTAssertTrue(model.remoteSettings.setupWizardCompleted)
    }

    func testFeedbackBundle_creationInProjectArtifacts() throws {
        let model = AppModel()
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("FSDMXVisionFeedbackTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        let projectFolder = tempRoot.appendingPathComponent("MyShow", isDirectory: true)
        try model.saveShowProject(to: projectFolder)
        model.createFeedbackBundle(message: "Test issue details")
        let feedbackRoot = projectFolder
            .appendingPathComponent("Artifacts", isDirectory: true)
            .appendingPathComponent("Feedback", isDirectory: true)
        let paths = try FileManager.default.contentsOfDirectory(atPath: feedbackRoot.path)
        XCTAssertFalse(paths.isEmpty)
    }

    func testAIProviderInfo_mappingOpenAI() {
        let info = AIProviderInfo(providerID: "openai")
        XCTAssertEqual(info.displayName, "OpenAI-compatible")
        XCTAssertEqual(info.apiWebsite, "https://platform.openai.com/docs/api-reference")
        XCTAssertEqual(info.defaultBaseURLHint, "Base URL (empty = OpenAI-compatible default)")
        XCTAssertFalse(info.setupSteps.isEmpty)
    }

    func testAIProviderInfo_mappingAnthropicAlias() {
        let info = AIProviderInfo(providerID: "claude")
        XCTAssertEqual(info.displayName, "Claude (Anthropic)")
        XCTAssertEqual(info.apiWebsite, "https://www.anthropic.com/api")
        XCTAssertEqual(info.defaultBaseURLHint, "Base URL (empty = https://api.anthropic.com/v1/messages)")
        XCTAssertTrue(info.setupSteps.contains { $0.contains("Anthropic API key") })
    }

    func testLiveOutputRecordingQualityPreset_mapsCaptureSettings() {
        let perf = AppModel.LiveOutputRecordingQualityPreset.performance.captureQuality
        XCTAssertEqual(perf.framesPerSecond, 24)
        XCTAssertEqual(perf.videoBitrate, 5_000_000)

        let balanced = AppModel.LiveOutputRecordingQualityPreset.balanced.captureQuality
        XCTAssertEqual(balanced.framesPerSecond, 30)
        XCTAssertEqual(balanced.videoBitrate, 8_000_000)

        let archival = AppModel.LiveOutputRecordingQualityPreset.archival.captureQuality
        XCTAssertEqual(archival.framesPerSecond, 60)
        XCTAssertEqual(archival.videoBitrate, 16_000_000)
    }

    func testRecordingHealthPermissionMessages() {
        XCTAssertEqual(
            AppModel.screenCapturePermissionHealthMessage(isGranted: true),
            "Screen recording permission granted."
        )
        XCTAssertEqual(
            AppModel.screenCapturePermissionHealthMessage(isGranted: false),
            "Screen recording permission missing. Enable it in System Settings > Privacy & Security > Screen Recording."
        )
        XCTAssertEqual(
            AppModel.audioPermissionHealthMessage(status: .authorized),
            "Microphone permission granted."
        )
        XCTAssertEqual(
            AppModel.audioPermissionHealthMessage(status: .notDetermined),
            "Microphone permission not determined. Starting recording will prompt for access."
        )
    }

    func testSetupWizard_analyticsAndDiagnosticsExport() throws {
        let model = AppModel()
        model.resetSetupWizard()
        model.beginSetupWizardSessionIfNeeded()
        model.markSetupWizardStep("audio", skipped: true)
        model.markSetupWizardStep("output", skipped: false)
        model.completeSetupWizard()

        XCTAssertGreaterThanOrEqual(model.remoteSettings.setupWizardSessionCount, 1)
        XCTAssertGreaterThanOrEqual(model.remoteSettings.setupWizardStepSkippedCounts["audio"] ?? 0, 1)
        XCTAssertGreaterThanOrEqual(model.remoteSettings.setupWizardStepCompletedCounts["output"] ?? 0, 1)
        XCTAssertFalse(model.remoteSettings.setupWizardCompletedAtISO8601.isEmpty)

        model.exportSetupWizardDiagnostics()
        let onboardingRoot = model.projectArtifactsFolderURL().appendingPathComponent("Onboarding", isDirectory: true)
        let paths = try FileManager.default.contentsOfDirectory(atPath: onboardingRoot.path)
        XCTAssertFalse(paths.isEmpty)
    }
}
