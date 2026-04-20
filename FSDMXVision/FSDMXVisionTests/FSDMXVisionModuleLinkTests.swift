import XCTest
@testable import FSDMXVision

final class FSDMXVisionModuleLinkTests: XCTestCase {
    func testSmoke_importsAppModule() {
        XCTAssertTrue(true, "Test target links against FSDMXVision")
    }
}
