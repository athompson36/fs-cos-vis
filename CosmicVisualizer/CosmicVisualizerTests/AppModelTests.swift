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
}
