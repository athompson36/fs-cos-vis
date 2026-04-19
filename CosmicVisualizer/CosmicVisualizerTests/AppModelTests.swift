import Metal
import XCTest
@testable import CosmicVisualizer

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
        XCTAssertEqual(model.sceneEditStates[id]?.layer.fractalExplore ?? 0, 0.66, accuracy: 0.01)
        XCTAssertEqual(model.sceneEditStates[id]?.layer.zoomEffectType ?? -1, 2, accuracy: 0.01)
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

    func testSaveShowProject_createsArtifactsAndBackupOnResave() throws {
        let model = AppModel()
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("CosmicVisualizerTests-\(UUID().uuidString)", isDirectory: true)
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
            .appendingPathComponent("CosmicVisualizerFeedbackTests-\(UUID().uuidString)", isDirectory: true)
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
