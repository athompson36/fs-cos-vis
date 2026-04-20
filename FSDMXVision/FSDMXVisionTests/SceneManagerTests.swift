import XCTest
@testable import FSDMXVision

final class SceneManagerTests: XCTestCase {
    func testEmptyScenes_noOp() {
        let mgr = SceneManager()
        XCTAssertTrue(mgr.scenes.isEmpty)
        mgr.goToNextScene()
        mgr.goToPreviousScene()
        XCTAssertEqual(mgr.currentIndex, 0)
    }

    func testNextPrevious_wraps() {
        let mgr = SceneManager()
        mgr.scenes = [
            VisualizationScene(name: "A", fractalMode: "julia", liquidLightEnabled: true),
            VisualizationScene(name: "B", fractalMode: "mandel", liquidLightEnabled: false),
        ]
        XCTAssertEqual(mgr.currentIndex, 0)
        mgr.goToNextScene()
        XCTAssertEqual(mgr.currentIndex, 1)
        mgr.goToNextScene()
        XCTAssertEqual(mgr.currentIndex, 0)
        mgr.goToPreviousScene()
        XCTAssertEqual(mgr.currentIndex, 1)
    }

    func testRandom_changesIndexWhenMultipleScenes() {
        let mgr = SceneManager()
        mgr.scenes = [
            VisualizationScene(name: "A", fractalMode: "julia", liquidLightEnabled: true),
            VisualizationScene(name: "B", fractalMode: "mandel", liquidLightEnabled: false),
        ]
        mgr.goToRandomScene()
        XCTAssertTrue(mgr.currentIndex == 0 || mgr.currentIndex == 1)
    }
}
