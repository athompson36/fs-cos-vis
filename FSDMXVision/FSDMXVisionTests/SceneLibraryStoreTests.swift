import XCTest
@testable import FSDMXVision

final class SceneLibraryStoreTests: XCTestCase {
    func testRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cv-scenes-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = SceneLibraryStore(fileURL: url)
        let scenes = [
            VisualizationScene(name: "A", fractalMode: "julia", liquidLightEnabled: true),
            VisualizationScene(name: "B", fractalMode: "mandel", liquidLightEnabled: false),
        ]
        try store.save(scenes: scenes)
        let doc = try XCTUnwrap(try store.load())
        XCTAssertEqual(doc.scenes, scenes)
    }
}
