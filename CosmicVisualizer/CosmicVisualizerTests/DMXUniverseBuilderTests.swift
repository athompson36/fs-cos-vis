import XCTest
@testable import CosmicVisualizer

final class DMXUniverseBuilderTests: XCTestCase {
    func testLegacySlotsFillFirstFiveChannels() {
        let model = AppModel()
        model.sceneManager.currentIndex = 2
        var smooth: [UUID: Float] = [:]
        let u = model.buildDMXUniverse(time: 0, lastSmoothed: &smooth)
        XCTAssertEqual(u.count, 512)
        XCTAssertEqual(u[0], 2)
    }

    func testCueMapOverridesChannel() {
        let model = AppModel()
        var doc = LightingCueDocument.default()
        doc.cues = [
            LightingCue(name: "Full", channelValues: [ChannelValue(channel: 10, value: 128)]),
        ]
        doc.activeCueIndex = 0
        model.applyLightingCueDocument(doc)
        var smooth: [UUID: Float] = [:]
        let u = model.buildDMXUniverse(time: 0, lastSmoothed: &smooth)
        XCTAssertEqual(u[9], 128)
    }
}
