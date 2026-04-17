import XCTest
@testable import CosmicVisualizer

final class FixtureVerificationTests: XCTestCase {
    func testStageLayoutDocument_decodesLegacyWithoutBackdropPlacement() throws {
        let json = """
        {"version":1,"backdropAssetPath":"/tmp/backdrop.png","placements":{}}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(StageLayoutDocument.self, from: json)
        XCTAssertEqual(decoded.backdropPlacement.centerX, 0.5, accuracy: 0.0001)
        XCTAssertEqual(decoded.backdropPlacement.centerY, 0.5, accuracy: 0.0001)
        XCTAssertEqual(decoded.backdropPlacement.scale, 1.0, accuracy: 0.0001)
        XCTAssertTrue(decoded.backdropPlacement.isVisible)
    }

    func testFixtureVerificationEvaluator_patchingAndQuantity() {
        let passPatch = FixtureVerificationEvaluator.patchingResult(lumaDelta: 0.08, threshold: 0.03)
        XCTAssertEqual(passPatch.status, .pass)

        let failPatch = FixtureVerificationEvaluator.patchingResult(lumaDelta: 0.01, threshold: 0.03)
        XCTAssertEqual(failPatch.status, .fail)

        let full = FixtureVerificationEvaluator.quantityResult(expected: 4, scanned: 4)
        XCTAssertEqual(full.status, .pass)

        let partial = FixtureVerificationEvaluator.quantityResult(expected: 4, scanned: 2)
        XCTAssertEqual(partial.status, .warn)
    }

    func testFixtureVerificationEvaluator_layoutAndOrientation() {
        let layoutWarn = FixtureVerificationEvaluator.layoutResult(expectedPlacement: nil)
        XCTAssertEqual(layoutWarn.status, .warn)

        let placement = StagePlacement(x: 0.35, y: 0.72, rotation: 30)
        let layoutPass = FixtureVerificationEvaluator.layoutResult(expectedPlacement: placement)
        XCTAssertEqual(layoutPass.status, .pass)

        let movingProfile = FixtureProfile(
            name: "Moving Head",
            channels: [
                FixtureChannelDef(label: "Dimmer", role: .intensity),
                FixtureChannelDef(label: "Pan", role: .pan),
                FixtureChannelDef(label: "Tilt", role: .tilt),
            ]
        )
        let orientPass = FixtureVerificationEvaluator.orientationResult(profile: movingProfile, placement: placement)
        XCTAssertEqual(orientPass.status, .pass)

        let staticProfile = FixtureProfile(name: "PAR", channels: [FixtureChannelDef(label: "Dimmer", role: .intensity)])
        let orientWarn = FixtureVerificationEvaluator.orientationResult(profile: staticProfile, placement: placement)
        XCTAssertEqual(orientWarn.status, .warn)
    }
}
