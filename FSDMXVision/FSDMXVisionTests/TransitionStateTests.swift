import XCTest
@testable import FSDMXVision

final class TransitionStateTests: XCTestCase {
    func testAdvance_reachesIdle() {
        let a = UUID()
        let b = UUID()
        var s = TransitionState.transitioning(fromSceneID: a, toSceneID: b, progress: 0)
        s.advance(by: 0.6)
        if case .transitioning(_, _, let p) = s {
            XCTAssertEqual(p, 0.6, accuracy: 0.001)
        } else {
            XCTFail("expected transitioning")
        }
        s.advance(by: 0.5)
        XCTAssertEqual(s, .idle)
    }

    func testCodable_roundTrip() throws {
        let a = UUID()
        let b = UUID()
        let original = TransitionState.transitioning(fromSceneID: a, toSceneID: b, progress: 0.25)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TransitionState.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
