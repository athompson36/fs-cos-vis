import XCTest
@testable import FSDMXVision

final class ExternalDisplayRouterTests: XCTestCase {
    func testScreens_nonEmptyOnMac() {
        XCTAssertFalse(ExternalDisplayRouter.screens.isEmpty)
    }

    func testPerformanceFrame_finite() {
        guard let main = ExternalDisplayRouter.screens.first else { return }
        let f = ExternalDisplayRouter.performanceFrame(on: main)
        XCTAssertGreaterThan(f.width, 0)
        XCTAssertGreaterThan(f.height, 0)
    }

    func testPerformanceAspectRatio_matchesScreenFrame() {
        guard let main = ExternalDisplayRouter.screens.first else { return }
        let f = main.frame
        let ar = ExternalDisplayRouter.performanceAspectRatio(screenIndex: 0)
        let expected = f.width / f.height
        XCTAssertEqual(ar, expected, accuracy: 0.001)
    }

    func testDefaultPreferredScreenIndex_inRange() {
        let idx = ExternalDisplayRouter.defaultPreferredScreenIndex()
        XCTAssertGreaterThanOrEqual(idx, 0)
        XCTAssertLessThan(idx, ExternalDisplayRouter.screens.count)
    }

    func testDisplayName_nonEmpty() {
        guard let s = ExternalDisplayRouter.screens.first else { return }
        XCTAssertFalse(ExternalDisplayRouter.displayName(for: s, index: 0).isEmpty)
    }
}
