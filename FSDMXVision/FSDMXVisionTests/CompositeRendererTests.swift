import XCTest
@testable import FSDMXVision

final class CompositeRendererTests: XCTestCase {
    func testCreate_succeedsWithMetal() throws {
        guard let r = CompositeRenderer.create() else {
            throw XCTSkip("Metal or shader pipeline unavailable")
        }
        XCTAssertNotNil(r.device)
    }
}
