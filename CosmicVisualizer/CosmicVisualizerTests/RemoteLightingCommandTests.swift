import XCTest
@testable import CosmicVisualizer

final class RemoteLightingCommandTests: XCTestCase {
    func testSetActiveLightingCueIndex_remote() {
        let model = AppModel()
        var doc = LightingCueDocument(version: 1, cues: [], activeCueIndex: nil)
        doc.cues = [
            LightingCue(name: "One", channelValues: []),
            LightingCue(name: "Two", channelValues: []),
        ]
        model.applyLightingCueDocument(doc)
        model.applyRemoteCommand(RemoteControlCommand(type: "SetActiveLightingCueIndex", index: 1))
        XCTAssertEqual(model.lightingCueDocument.activeCueIndex, 1)
    }

    func testSetActiveLightingCueIndex_clearWhenIndexOmitted() {
        let model = AppModel()
        var doc = LightingCueDocument(version: 1, cues: [], activeCueIndex: nil)
        doc.cues = [LightingCue(name: "A", channelValues: [])]
        doc.activeCueIndex = 0
        model.applyLightingCueDocument(doc)
        model.applyRemoteCommand(RemoteControlCommand(type: "SetActiveLightingCueIndex"))
        XCTAssertNil(model.lightingCueDocument.activeCueIndex)
    }

    func testNextLightingCue_wraps() {
        let model = AppModel()
        var doc = LightingCueDocument(version: 1, cues: [], activeCueIndex: nil)
        doc.cues = [
            LightingCue(name: "A", channelValues: []),
            LightingCue(name: "B", channelValues: []),
        ]
        doc.activeCueIndex = 1
        model.applyLightingCueDocument(doc)
        model.applyRemoteCommand(RemoteControlCommand(type: "NextLightingCue"))
        XCTAssertEqual(model.lightingCueDocument.activeCueIndex, 0)
    }

    func testPreviousLightingCue_wraps() {
        let model = AppModel()
        var doc = LightingCueDocument(version: 1, cues: [], activeCueIndex: nil)
        doc.cues = [
            LightingCue(name: "A", channelValues: []),
            LightingCue(name: "B", channelValues: []),
        ]
        doc.activeCueIndex = 0
        model.applyLightingCueDocument(doc)
        model.applyRemoteCommand(RemoteControlCommand(type: "PreviousLightingCue"))
        XCTAssertEqual(model.lightingCueDocument.activeCueIndex, 1)
    }
}
