import XCTest
@testable import FSDMXVision

final class SceneControlStoreTests: XCTestCase {
    func testRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("scene_controls_test.json")
        try? FileManager.default.removeItem(at: url)
        let store = SceneControlStore(fileURL: url)
        let id = UUID()
        let states = [id: SceneEditState(layer: .init(fractalZoom: 1.2, fractalColorSpeed: 1, liquidTurbulence: 1.1, compositeBlend: 0.5))]
        try store.save(states: states)
        let doc = try XCTUnwrap(try store.load())
        XCTAssertEqual(doc.states[id]?.layer.fractalZoom, 1.2)
    }
}
