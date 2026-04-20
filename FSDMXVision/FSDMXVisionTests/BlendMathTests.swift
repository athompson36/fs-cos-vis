import XCTest
@testable import FSDMXVision

final class BlendMathTests: XCTestCase {
    func testScreen_blendWithBlack_returnsOriginal() {
        let a = SIMD3<Float>(0.5, 0.25, 0.75)
        let b = SIMD3<Float>(0, 0, 0)
        let r = BlendMath.screen(a, b)
        XCTAssertEqual(r.x, a.x, accuracy: 1e-5)
        XCTAssertEqual(r.y, a.y, accuracy: 1e-5)
        XCTAssertEqual(r.z, a.z, accuracy: 1e-5)
    }

    func testAdd() {
        let a = SIMD3<Float>(0.1, 0.2, 0.3)
        let b = SIMD3<Float>(0.4, 0.5, 0.6)
        let r = BlendMath.add(a, b)
        let e = SIMD3<Float>(0.5, 0.7, 0.9)
        XCTAssertEqual(r.x, e.x, accuracy: 1e-5)
        XCTAssertEqual(r.y, e.y, accuracy: 1e-5)
        XCTAssertEqual(r.z, e.z, accuracy: 1e-5)
    }
}
