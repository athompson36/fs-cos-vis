import Foundation
import XCTest
@testable import FSDMXVision

@MainActor
private final class FakeVisualSceneController: VisualSceneControlling {
    var ids: [UUID]
    var activeID: UUID?
    var thrownError: Error?
    var verificationOverrideID: UUID?
    var mutationAdvance: (() -> Void)?

    init(ids: [UUID], activeID: UUID? = nil) {
        self.ids = ids
        self.activeID = activeID
    }

    func visualSceneIDs() -> [UUID] { ids }
    func activeVisualSceneID() -> UUID? { verificationOverrideID ?? activeID }
    func recallVisualScene(id: UUID) throws {
        if let thrownError { throw thrownError }
        activeID = id
        mutationAdvance?()
    }
}

@MainActor
private final class FakePaletteController: PaletteControlling {
    var ids: [UUID]
    var activeID: UUID?
    var thrownError: Error?
    var verificationOverrideID: UUID?
    var mutationAdvance: (() -> Void)?

    init(ids: [UUID], activeID: UUID? = nil) {
        self.ids = ids
        self.activeID = activeID
    }

    func paletteIDs() -> [UUID] { ids }
    func activePaletteID() -> UUID? { verificationOverrideID ?? activeID }
    func selectPalette(id: UUID) throws {
        if let thrownError { throw thrownError }
        activeID = id
        mutationAdvance?()
    }
}

@MainActor
private final class FakeLightingCueController: LightingCueControlling {
    var ids: [UUID]
    var activeID: UUID?
    var thrownError: Error?
    var verificationOverrideID: UUID?
    var fadeSecondsByID: [UUID: Double]
    var mutationAdvance: (() -> Void)?

    init(ids: [UUID], activeID: UUID? = nil, fadeSecondsByID: [UUID: Double] = [:]) {
        self.ids = ids
        self.activeID = activeID
        self.fadeSecondsByID = fadeSecondsByID
    }

    func lightingCueIDs() -> [UUID] { ids }
    func activeLightingCueID() -> UUID? { verificationOverrideID ?? activeID }
    func recallLightingCue(id: UUID) throws {
        if let thrownError { throw thrownError }
        activeID = id
        mutationAdvance?()
    }
    func lightingCueFadeSeconds(id: UUID) -> Double? { fadeSecondsByID[id] }
}

private enum AdapterTestError: Error, LocalizedError {
    case mutationFailed

    var errorDescription: String? { "Mutation failed." }
}

@MainActor
final class ShowDirectorRealAdapterTests: XCTestCase {
    private let context = ShowExecutionContext(
        showID: "show",
        commandID: "command",
        cuePackageID: "package",
        runtimeRevision: 1
    )

    // MARK: Visual scenes

    func testVisualValidationAcceptsMatchingScene() async {
        let target = UUID()
        let adapter = VisualSceneEndpointAdapter(
            controller: FakeVisualSceneController(ids: [target]),
            clock: ControllableShowDirectorClock()
        )

        let result = await adapter.validate(
            .recallVisualScene(id: "visual", sceneID: target.uuidString, fadeMilliseconds: 500),
            context: context
        )

        XCTAssertEqual(result, .valid)
    }

    func testVisualValidationRejectsWrongMalformedAndMissingTargets() async {
        let target = UUID()
        let adapter = VisualSceneEndpointAdapter(
            controller: FakeVisualSceneController(ids: [target]),
            clock: ControllableShowDirectorClock()
        )

        let wrong = await adapter.validate(
            .applyPalette(id: "wrong", paletteID: target.uuidString, fadeMilliseconds: 0),
            context: context
        )
        let malformed = await adapter.validate(
            .recallVisualScene(id: "malformed", sceneID: "not-a-uuid", fadeMilliseconds: 0),
            context: context
        )
        let missing = await adapter.validate(
            .recallVisualScene(id: "missing", sceneID: UUID().uuidString, fadeMilliseconds: 0),
            context: context
        )

        assertInvalid(wrong)
        assertInvalid(malformed)
        assertInvalid(missing)
    }

    func testVisualExecutionMutatesVerifiesMeasuresAndReportsPolicy() async {
        let target = UUID()
        let clock = ControllableShowDirectorClock()
        let controller = FakeVisualSceneController(ids: [target])
        controller.mutationAdvance = { clock.advance(seconds: 0.125) }
        let adapter = VisualSceneEndpointAdapter(controller: controller, clock: clock)

        let result = await adapter.execute(
            .recallVisualScene(id: "visual", sceneID: target.uuidString, fadeMilliseconds: 900),
            context: context
        )

        XCTAssertEqual(controller.activeID, target)
        XCTAssertEqual(result.status, .executed)
        XCTAssertEqual(result.durationMilliseconds, 125)
        XCTAssertEqual(
            result.message,
            "Scene recalled; requested fadeMs is advisory and the app transition is active."
        )
    }

    func testVisualExecutionRevalidatesImmediatelyBeforeMutation() async {
        let target = UUID()
        let controller = FakeVisualSceneController(ids: [target])
        let adapter = VisualSceneEndpointAdapter(
            controller: controller,
            clock: ControllableShowDirectorClock()
        )
        controller.ids = []

        let result = await adapter.execute(
            .recallVisualScene(id: "visual", sceneID: target.uuidString, fadeMilliseconds: 0),
            context: context
        )

        XCTAssertEqual(result.status, .validationFailed)
        XCTAssertNil(controller.activeID)
    }

    func testVisualVerificationFailureDegradesUntilSuccessfulExecution() async {
        let target = UUID()
        let controller = FakeVisualSceneController(ids: [target])
        controller.verificationOverrideID = UUID()
        let clock = ControllableShowDirectorClock()
        let adapter = VisualSceneEndpointAdapter(controller: controller, clock: clock)

        let failed = await adapter.execute(
            .recallVisualScene(id: "visual-fail", sceneID: target.uuidString, fadeMilliseconds: 0),
            context: context
        )
        let degraded = await adapter.currentHealth()
        controller.verificationOverrideID = nil
        let succeeded = await adapter.execute(
            .recallVisualScene(id: "visual-success", sceneID: target.uuidString, fadeMilliseconds: 0),
            context: context
        )
        let restored = await adapter.currentHealth()

        XCTAssertEqual(failed.status, .failed)
        XCTAssertEqual(degraded.status, .degraded)
        XCTAssertNotNil(degraded.message)
        XCTAssertEqual(succeeded.status, .executed)
        XCTAssertEqual(restored.status, .available)
        XCTAssertNil(restored.message)
    }

    func testVisualMutationFailureDegradesHealth() async {
        let target = UUID()
        let controller = FakeVisualSceneController(ids: [target])
        controller.thrownError = AdapterTestError.mutationFailed
        let adapter = VisualSceneEndpointAdapter(
            controller: controller,
            clock: ControllableShowDirectorClock()
        )

        let result = await adapter.execute(
            .recallVisualScene(id: "visual", sceneID: target.uuidString, fadeMilliseconds: 0),
            context: context
        )
        let health = await adapter.currentHealth()

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(health.status, .degraded)
        XCTAssertEqual(health.message, result.message)
    }

    func testVisualHealthReflectsEmptyAndNonemptyLibrary() async {
        let controller = FakeVisualSceneController(ids: [])
        let clock = ControllableShowDirectorClock()
        let adapter = VisualSceneEndpointAdapter(controller: controller, clock: clock)

        let empty = await adapter.currentHealth()
        controller.ids = [UUID()]
        clock.advance(seconds: 1)
        let nonempty = await adapter.currentHealth()

        XCTAssertEqual(empty.status, .unavailable)
        XCTAssertEqual(empty.message, "No visual scenes are available.")
        XCTAssertEqual(nonempty.status, .available)
        XCTAssertNil(nonempty.message)
        XCTAssertEqual(nonempty.observedAt.timeIntervalSince(empty.observedAt), 1, accuracy: 0.001)
    }

    // MARK: Palettes

    func testPaletteValidationAcceptsMatchingPalette() async {
        let target = UUID()
        let adapter = PaletteEndpointAdapter(
            controller: FakePaletteController(ids: [target]),
            clock: ControllableShowDirectorClock()
        )

        let result = await adapter.validate(
            .applyPalette(id: "palette", paletteID: target.uuidString, fadeMilliseconds: 500),
            context: context
        )

        XCTAssertEqual(result, .valid)
    }

    func testPaletteValidationRejectsWrongMalformedAndMissingTargets() async {
        let target = UUID()
        let adapter = PaletteEndpointAdapter(
            controller: FakePaletteController(ids: [target]),
            clock: ControllableShowDirectorClock()
        )

        let wrong = await adapter.validate(
            .recallVisualScene(id: "wrong", sceneID: target.uuidString, fadeMilliseconds: 0),
            context: context
        )
        let malformed = await adapter.validate(
            .applyPalette(id: "malformed", paletteID: "not-a-uuid", fadeMilliseconds: 0),
            context: context
        )
        let missing = await adapter.validate(
            .applyPalette(id: "missing", paletteID: UUID().uuidString, fadeMilliseconds: 0),
            context: context
        )

        assertInvalid(wrong)
        assertInvalid(malformed)
        assertInvalid(missing)
    }

    func testPaletteExecutionMutatesVerifiesMeasuresAndReportsPolicy() async {
        let target = UUID()
        let clock = ControllableShowDirectorClock()
        let controller = FakePaletteController(ids: [target])
        controller.mutationAdvance = { clock.advance(seconds: 0.042) }
        let adapter = PaletteEndpointAdapter(controller: controller, clock: clock)

        let result = await adapter.execute(
            .applyPalette(id: "palette", paletteID: target.uuidString, fadeMilliseconds: 900),
            context: context
        )

        XCTAssertEqual(controller.activeID, target)
        XCTAssertEqual(result.status, .executed)
        XCTAssertEqual(result.durationMilliseconds, 42)
        XCTAssertEqual(result.message, "Palette applied immediately; requested fadeMs is advisory.")
    }

    func testPaletteExecutionRevalidatesImmediatelyBeforeMutation() async {
        let target = UUID()
        let controller = FakePaletteController(ids: [target])
        let adapter = PaletteEndpointAdapter(
            controller: controller,
            clock: ControllableShowDirectorClock()
        )
        controller.ids = []

        let result = await adapter.execute(
            .applyPalette(id: "palette", paletteID: target.uuidString, fadeMilliseconds: 0),
            context: context
        )

        XCTAssertEqual(result.status, .validationFailed)
        XCTAssertNil(controller.activeID)
    }

    func testPaletteVerificationFailureDegradesUntilSuccessfulExecution() async {
        let target = UUID()
        let controller = FakePaletteController(ids: [target])
        controller.verificationOverrideID = UUID()
        let adapter = PaletteEndpointAdapter(
            controller: controller,
            clock: ControllableShowDirectorClock()
        )

        let failed = await adapter.execute(
            .applyPalette(id: "palette-fail", paletteID: target.uuidString, fadeMilliseconds: 0),
            context: context
        )
        let degraded = await adapter.currentHealth()
        controller.verificationOverrideID = nil
        let succeeded = await adapter.execute(
            .applyPalette(id: "palette-success", paletteID: target.uuidString, fadeMilliseconds: 0),
            context: context
        )
        let restored = await adapter.currentHealth()

        XCTAssertEqual(failed.status, .failed)
        XCTAssertEqual(degraded.status, .degraded)
        XCTAssertNotNil(degraded.message)
        XCTAssertEqual(succeeded.status, .executed)
        XCTAssertEqual(restored.status, .available)
        XCTAssertNil(restored.message)
    }

    func testPaletteMutationFailureDegradesHealth() async {
        let target = UUID()
        let controller = FakePaletteController(ids: [target])
        controller.thrownError = AdapterTestError.mutationFailed
        let adapter = PaletteEndpointAdapter(
            controller: controller,
            clock: ControllableShowDirectorClock()
        )

        let result = await adapter.execute(
            .applyPalette(id: "palette", paletteID: target.uuidString, fadeMilliseconds: 0),
            context: context
        )
        let health = await adapter.currentHealth()

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(health.status, .degraded)
        XCTAssertEqual(health.message, result.message)
    }

    func testPaletteHealthReflectsEmptyAndNonemptyLibrary() async {
        let controller = FakePaletteController(ids: [])
        let adapter = PaletteEndpointAdapter(
            controller: controller,
            clock: ControllableShowDirectorClock()
        )

        let empty = await adapter.currentHealth()
        controller.ids = [UUID()]
        let nonempty = await adapter.currentHealth()

        XCTAssertEqual(empty.status, .unavailable)
        XCTAssertEqual(empty.message, "No palettes are available.")
        XCTAssertEqual(nonempty.status, .available)
        XCTAssertNil(nonempty.message)
    }

    // MARK: Lighting cues

    func testLightingValidationAcceptsMatchingCue() async {
        let target = UUID()
        let adapter = LightingCueEndpointAdapter(
            controller: FakeLightingCueController(ids: [target]),
            clock: ControllableShowDirectorClock()
        )

        let result = await adapter.validate(
            .recallLightingCue(id: "lighting", cueID: target.uuidString),
            context: context
        )

        XCTAssertEqual(result, .valid)
    }

    func testLightingValidationRejectsWrongMalformedAndMissingTargets() async {
        let target = UUID()
        let adapter = LightingCueEndpointAdapter(
            controller: FakeLightingCueController(ids: [target]),
            clock: ControllableShowDirectorClock()
        )

        let wrong = await adapter.validate(
            .recallLightingScene(id: "wrong", sceneID: target.uuidString, fadeMilliseconds: 0),
            context: context
        )
        let malformed = await adapter.validate(
            .recallLightingCue(id: "malformed", cueID: "not-a-uuid"),
            context: context
        )
        let missing = await adapter.validate(
            .recallLightingCue(id: "missing", cueID: UUID().uuidString),
            context: context
        )

        assertInvalid(wrong)
        assertInvalid(malformed)
        assertInvalid(missing)
    }

    func testLightingExecutionMutatesVerifiesMeasuresAndReportsPersistedFade() async {
        let target = UUID()
        let clock = ControllableShowDirectorClock()
        let controller = FakeLightingCueController(
            ids: [target],
            fadeSecondsByID: [target: 1.25]
        )
        controller.mutationAdvance = { clock.advance(seconds: 0.2) }
        let adapter = LightingCueEndpointAdapter(controller: controller, clock: clock)

        let result = await adapter.execute(
            .recallLightingCue(id: "lighting", cueID: target.uuidString),
            context: context
        )

        XCTAssertEqual(controller.activeID, target)
        XCTAssertEqual(result.status, .executed)
        XCTAssertEqual(result.durationMilliseconds, 200)
        XCTAssertEqual(result.message, "Lighting cue recalled using its persisted fade of 1.25s.")
    }

    func testLightingFadeFormattingIsPOSIXAndDeterministic() async {
        let target = UUID()
        let controller = FakeLightingCueController(
            ids: [target],
            fadeSecondsByID: [target: 1234.0]
        )
        let adapter = LightingCueEndpointAdapter(
            controller: controller,
            clock: ControllableShowDirectorClock()
        )

        let result = await adapter.execute(
            .recallLightingCue(id: "lighting", cueID: target.uuidString),
            context: context
        )

        XCTAssertEqual(result.message, "Lighting cue recalled using its persisted fade of 1.23e+03s.")
    }

    func testLightingExecutionRevalidatesImmediatelyBeforeMutation() async {
        let target = UUID()
        let controller = FakeLightingCueController(ids: [target], fadeSecondsByID: [target: 1])
        let adapter = LightingCueEndpointAdapter(
            controller: controller,
            clock: ControllableShowDirectorClock()
        )
        controller.ids = []

        let result = await adapter.execute(
            .recallLightingCue(id: "lighting", cueID: target.uuidString),
            context: context
        )

        XCTAssertEqual(result.status, .validationFailed)
        XCTAssertNil(controller.activeID)
    }

    func testLightingVerificationFailureDegradesUntilSuccessfulExecution() async {
        let target = UUID()
        let controller = FakeLightingCueController(ids: [target], fadeSecondsByID: [target: 1])
        controller.verificationOverrideID = UUID()
        let adapter = LightingCueEndpointAdapter(
            controller: controller,
            clock: ControllableShowDirectorClock()
        )

        let failed = await adapter.execute(
            .recallLightingCue(id: "lighting-fail", cueID: target.uuidString),
            context: context
        )
        let degraded = await adapter.currentHealth()
        controller.verificationOverrideID = nil
        let succeeded = await adapter.execute(
            .recallLightingCue(id: "lighting-success", cueID: target.uuidString),
            context: context
        )
        let restored = await adapter.currentHealth()

        XCTAssertEqual(failed.status, .failed)
        XCTAssertEqual(degraded.status, .degraded)
        XCTAssertNotNil(degraded.message)
        XCTAssertEqual(succeeded.status, .executed)
        XCTAssertEqual(restored.status, .available)
        XCTAssertNil(restored.message)
    }

    func testLightingMutationFailureDegradesHealth() async {
        let target = UUID()
        let controller = FakeLightingCueController(ids: [target], fadeSecondsByID: [target: 1])
        controller.thrownError = AdapterTestError.mutationFailed
        let adapter = LightingCueEndpointAdapter(
            controller: controller,
            clock: ControllableShowDirectorClock()
        )

        let result = await adapter.execute(
            .recallLightingCue(id: "lighting", cueID: target.uuidString),
            context: context
        )
        let health = await adapter.currentHealth()

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(health.status, .degraded)
        XCTAssertEqual(health.message, result.message)
    }

    func testLightingHealthReflectsEmptyAndNonemptyLibrary() async {
        let controller = FakeLightingCueController(ids: [])
        let adapter = LightingCueEndpointAdapter(
            controller: controller,
            clock: ControllableShowDirectorClock()
        )

        let empty = await adapter.currentHealth()
        controller.ids = [UUID()]
        let nonempty = await adapter.currentHealth()

        XCTAssertEqual(empty.status, .unavailable)
        XCTAssertEqual(empty.message, "No lighting cues are available.")
        XCTAssertEqual(nonempty.status, .available)
        XCTAssertNil(nonempty.message)
    }

    private func assertInvalid(
        _ result: ShowActionValidationResult,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .invalid(let message) = result else {
            return XCTFail("Expected invalid validation result.", file: file, line: line)
        }
        XCTAssertFalse(message.isEmpty, file: file, line: line)
    }
}
