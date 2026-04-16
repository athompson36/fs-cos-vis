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
}
