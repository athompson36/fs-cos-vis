import XCTest
@testable import FSDMXVision

final class ControlPlanePortBindingTests: XCTestCase {
    func testClampUserPort_respectsBounds() {
        XCTAssertEqual(ControlPlanePortBinding.clampUserPort(100), 1024)
        XCTAssertEqual(ControlPlanePortBinding.clampUserPort(8765), 8765)
        XCTAssertEqual(ControlPlanePortBinding.clampUserPort(999_999), 65_535)
    }

    func testFirstAvailableTCPPort_findsLoopbackPort() {
        // High ephemeral range is unlikely to collide with the HTTP default (8765) on a dev machine.
        let found = ControlPlanePortBinding.firstAvailableTCPPort(startingAt: 59_000, bindLAN: false, maxAttempts: 8)
        XCTAssertNotNil(found)
    }
}
