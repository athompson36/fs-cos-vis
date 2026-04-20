import XCTest
@testable import FSDMXVision

final class OverlayBlendModeTests: XCTestCase {
    func testRawValues_distinct() {
        let raws = Set(OverlayBlendMode.allCases.map(\.rawValue))
        XCTAssertEqual(raws.count, OverlayBlendMode.allCases.count)
    }
}
