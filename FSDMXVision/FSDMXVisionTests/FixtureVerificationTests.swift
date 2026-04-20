import XCTest
@testable import FSDMXVision

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

    func testResolvedProbeDelta_prefersStrongerSecondaryWhenAvailable() {
        let resolved = FixtureVerificationService.resolvedProbeDelta(
            primaryBaseline: 0.20,
            primaryLit: 0.28,
            secondaryBaseline: 0.21,
            secondaryLit: 0.40
        )
        XCTAssertEqual(resolved.delta, 0.19, accuracy: 0.0001)
        XCTAssertTrue(resolved.usedSecondary)
    }

    func testResolvedProbeDelta_fallsBackToPrimaryWhenSecondaryUnavailable() {
        let resolved = FixtureVerificationService.resolvedProbeDelta(
            primaryBaseline: 0.33,
            primaryLit: 0.39,
            secondaryBaseline: nil,
            secondaryLit: nil
        )
        XCTAssertEqual(resolved.delta, 0.06, accuracy: 0.0001)
        XCTAssertFalse(resolved.usedSecondary)
    }

    func testStageLayoutDocument_decodesLegacyWithoutScanCameras() throws {
        let json = """
        {"version":1,"placements":{}}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(StageLayoutDocument.self, from: json)
        XCTAssertTrue(decoded.primaryScanCamera.isEnabled)
        XCTAssertEqual(decoded.primaryScanCamera.label, "Primary scan")
        XCTAssertFalse(decoded.secondaryScanCamera.isEnabled)
        XCTAssertEqual(decoded.secondaryScanCamera.label, "Secondary iOS scan")
    }

    func testStageLayoutDocument_scanCamerasRoundTrip() throws {
        let original = StageLayoutDocument(
            primaryScanCamera: StageScanCameraPlacement(
                isEnabled: true,
                label: "FOH cam",
                x: 0.12,
                y: 0.08,
                angleDeg: 20,
                fovDeg: 72
            ),
            secondaryScanCamera: StageScanCameraPlacement(
                isEnabled: true,
                label: "Pit cam",
                x: 0.86,
                y: 0.18,
                angleDeg: -28,
                fovDeg: 58
            )
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StageLayoutDocument.self, from: data)
        XCTAssertEqual(decoded.primaryScanCamera, original.primaryScanCamera)
        XCTAssertEqual(decoded.secondaryScanCamera, original.secondaryScanCamera)
    }

    func testStagePlotObject_normalizedFootprint_scalesToDimensions() {
        let object = StagePlotObject(
            templateID: "keyboard_rig",
            label: "Keys",
            footprintWidthMeters: 2.0,
            footprintDepthMeters: 1.0,
            scale: 1.5
        )
        let normalized = object.normalizedFootprint(in: StageDimensions(widthMeters: 10, depthMeters: 5))
        XCTAssertEqual(normalized.width, 0.3, accuracy: 0.0001)
        XCTAssertEqual(normalized.depth, 0.3, accuracy: 0.0001)
    }

    func testStagePlotObject_decodeLegacyWithoutIsLocked_defaultsFalse() throws {
        let json = """
        {
          "id":"00000000-0000-0000-0000-000000000999",
          "templateID":"drum_kit",
          "label":"Drums",
          "footprintWidthMeters":2.0,
          "footprintDepthMeters":1.5,
          "centerX":0.5,
          "centerY":0.4,
          "rotation":0,
          "scale":1
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(StagePlotObject.self, from: json)
        XCTAssertFalse(decoded.isLocked)
    }

    func testStagePlotObject_roundTripPersistsIsLocked() throws {
        let original = StagePlotObject(
            templateID: "dj_booth",
            label: "FOH DJ",
            footprintWidthMeters: 2.0,
            footprintDepthMeters: 1.0,
            isLocked: true
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StagePlotObject.self, from: data)
        XCTAssertEqual(decoded.isLocked, true)
    }

    func testFixtureVerificationRunStatus_phaseAndNotesTexts() {
        XCTAssertEqual(
            FixtureVerificationEvaluator.phaseText(status: .completed, scanned: 4, expected: 4),
            "Fixture verification complete (4/4)."
        )
        XCTAssertEqual(
            FixtureVerificationEvaluator.phaseText(status: .cancelled, scanned: 2, expected: 5),
            "Fixture verification cancelled (2/5)."
        )
        XCTAssertEqual(
            FixtureVerificationEvaluator.phaseText(status: .pausedPrimaryCameraDisconnected, scanned: 3, expected: 6),
            "Primary camera disconnected. Reconnect/reposition camera, then resume scan (3/6)."
        )
        XCTAssertTrue(
            FixtureVerificationEvaluator.notesText(status: .pausedPrimaryCameraDisconnected, usedSecondary: false)
                .contains("paused")
        )
    }

    func testFixtureVerificationSeverityAndFilterMatching() {
        let result = FixtureVerificationFixtureResult(
            fixtureID: UUID(),
            fixtureName: "PAR",
            fixtureIndex: 1,
            startAddress: 1,
            channelSpan: 4,
            expectedPlacement: StagePlacement(),
            observedLumaDelta: 0.02,
            patching: FixtureVerificationCategoryResult(status: .fail, note: "No response"),
            quantity: FixtureVerificationCategoryResult(status: .pass, note: "Scanned"),
            layout: FixtureVerificationCategoryResult(status: .warn, note: "Needs placement"),
            orientation: FixtureVerificationCategoryResult(status: .pass, note: "OK")
        )
        XCTAssertEqual(FixtureVerificationEvaluator.severity(for: result), .fail)
        XCTAssertTrue(FixtureVerificationEvaluator.matches(filter: .all, fixture: result))
        XCTAssertTrue(FixtureVerificationEvaluator.matches(filter: .fail, fixture: result))
        XCTAssertFalse(FixtureVerificationEvaluator.matches(filter: .warn, fixture: result))
        XCTAssertFalse(FixtureVerificationEvaluator.matches(filter: .pass, fixture: result))
    }

    func testFixtureVerificationExposureHint_lowLightAndOverexposure() {
        let lowLight = FixtureVerificationEvaluator.exposureHint(
            primaryBaseline: 0.03,
            primaryLit: 0.04,
            secondaryBaseline: nil,
            secondaryLit: nil,
            observedDelta: 0.01
        )
        XCTAssertEqual(
            lowLight,
            "Low-light feed; increase front light or camera gain for reliable verification."
        )

        let overExposed = FixtureVerificationEvaluator.exposureHint(
            primaryBaseline: 0.90,
            primaryLit: 0.98,
            secondaryBaseline: 0.91,
            secondaryLit: 0.99,
            observedDelta: 0.08
        )
        XCTAssertEqual(
            overExposed,
            "Overexposed camera feed; lower exposure or reduce ambient brightness."
        )

        let nominal = FixtureVerificationEvaluator.exposureHint(
            primaryBaseline: 0.30,
            primaryLit: 0.38,
            secondaryBaseline: nil,
            secondaryLit: nil,
            observedDelta: 0.08
        )
        XCTAssertNil(nominal)

        let weakContrast = FixtureVerificationEvaluator.exposureHint(
            primaryBaseline: 0.22,
            primaryLit: 0.34,
            secondaryBaseline: nil,
            secondaryLit: nil,
            observedDelta: 0.02
        )
        XCTAssertEqual(
            weakContrast,
            "Weak contrast on camera; adjust angle, zoom, or lock exposure if response stays borderline."
        )
    }

    func testFixtureVerificationEvaluator_confidenceScoreBounds() {
        let strong = FixtureVerificationFixtureResult(
            fixtureID: UUID(),
            fixtureName: "PAR",
            fixtureIndex: 1,
            startAddress: 1,
            channelSpan: 4,
            expectedPlacement: StagePlacement(x: 0.4, y: 0.5, rotation: 0),
            observedLumaDelta: 0.14,
            patching: FixtureVerificationCategoryResult(status: .pass, note: "ok"),
            quantity: FixtureVerificationCategoryResult(status: .pass, note: "ok"),
            layout: FixtureVerificationCategoryResult(status: .pass, note: "ok"),
            orientation: FixtureVerificationCategoryResult(status: .pass, note: "ok")
        )
        let cStrong = FixtureVerificationEvaluator.confidence01(for: strong)
        XCTAssertGreaterThan(cStrong, 0.85)
        XCTAssertLessThanOrEqual(cStrong, 1.0)

        let weak = FixtureVerificationFixtureResult(
            fixtureID: UUID(),
            fixtureName: "PAR",
            fixtureIndex: 1,
            startAddress: 1,
            channelSpan: 4,
            expectedPlacement: nil,
            observedLumaDelta: 0.01,
            patching: FixtureVerificationCategoryResult(status: .fail, note: "no"),
            quantity: FixtureVerificationCategoryResult(status: .warn, note: "partial"),
            layout: FixtureVerificationCategoryResult(status: .warn, note: "map"),
            orientation: FixtureVerificationCategoryResult(status: .warn, note: "map")
        )
        let cWeak = FixtureVerificationEvaluator.confidence01(for: weak)
        XCTAssertGreaterThanOrEqual(cWeak, 0)
        XCTAssertLessThan(cWeak, 0.55)

        let doc = FixtureVerificationDocument(
            fixtureCountExpected: 2,
            fixtureCountScanned: 2,
            fixtures: [strong, weak]
        )
        XCTAssertEqual(FixtureVerificationEvaluator.averageConfidencePercent(for: doc), Int(((cStrong + cWeak) / 2 * 100).rounded()))
    }
}
