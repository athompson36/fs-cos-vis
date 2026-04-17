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
}
