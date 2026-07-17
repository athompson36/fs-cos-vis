import XCTest
@testable import FSDMXVision

final class ShowDirectorReducerTests: XCTestCase {
    func testLoadShow_setsReadyAtFirstSection() {
        let graph = ShowDirectorFixtures.demoGraph()
        let result = ShowDirectorReducer.reduce(
            state: ShowDirectorReducerState(),
            command: .loadShow(commandID: "cmd_load", graph: graph)
        )
        XCTAssertEqual(result.disposition, .accepted)
        XCTAssertEqual(result.state.runtime.transport, .ready)
        XCTAssertEqual(result.state.runtime.activeSectionID, "section_intro")
        XCTAssertEqual(result.state.runtime.revision, 1)
        XCTAssertTrue(result.effects.contains(.publishState))
    }

    func testGo_fromReady_executesCurrentCue() {
        var state = loadedState()
        let result = ShowDirectorReducer.reduce(state: state, command: .go(commandID: "cmd_go1"))
        XCTAssertEqual(result.disposition, .accepted)
        XCTAssertEqual(result.state.runtime.transport, .running)
        XCTAssertTrue(result.effects.contains(.executeCuePackage(commandID: "cmd_go1", cuePackageID: "cue_aurora_intro")))
        state = result.state

        let held = ShowDirectorReducer.reduce(state: state, command: .hold(commandID: "cmd_hold"))
        XCTAssertEqual(held.state.runtime.transport, .held)
        let goWhileHeld = ShowDirectorReducer.reduce(state: held.state, command: .go(commandID: "cmd_go_held"))
        XCTAssertEqual(goWhileHeld.disposition, .noOp(reason: "Transport is held; GO does not execute."))
        XCTAssertTrue(goWhileHeld.effects.isEmpty)
    }

    func testGo_fromRunning_advancesToNextSection() {
        var state = loadedState()
        state = ShowDirectorReducer.reduce(state: state, command: .go(commandID: "cmd_go1")).state
        let result = ShowDirectorReducer.reduce(state: state, command: .go(commandID: "cmd_go2"))
        XCTAssertEqual(result.disposition, .accepted)
        XCTAssertEqual(result.state.runtime.activeSectionID, "section_drop")
        XCTAssertTrue(result.effects.contains(.executeCuePackage(commandID: "cmd_go2", cuePackageID: "cue_aurora_drop")))
    }

    func testHoldResumeRepeatJumpPreviousNextUndo() {
        var state = loadedState()
        state = ShowDirectorReducer.reduce(state: state, command: .go(commandID: "g1")).state
        state = ShowDirectorReducer.reduce(state: state, command: .hold(commandID: "h1")).state
        XCTAssertEqual(state.runtime.transport, .held)

        state = ShowDirectorReducer.reduce(state: state, command: .resume(commandID: "r1")).state
        XCTAssertEqual(state.runtime.transport, .running)

        let repeatResult = ShowDirectorReducer.reduce(state: state, command: .repeatSection(commandID: "rep1"))
        XCTAssertEqual(repeatResult.disposition, .accepted)
        state = repeatResult.state

        state = ShowDirectorReducer.reduce(state: state, command: .jumpToSection(commandID: "j1", sectionID: "section_drop")).state
        XCTAssertEqual(state.runtime.activeSectionID, "section_drop")

        state = ShowDirectorReducer.reduce(state: state, command: .previous(commandID: "p1")).state
        XCTAssertEqual(state.runtime.activeSectionID, "section_intro")

        state = ShowDirectorReducer.reduce(state: state, command: .next(commandID: "n1")).state
        XCTAssertEqual(state.runtime.activeSectionID, "section_drop")

        let beforeUndoRevision = state.runtime.revision
        state = ShowDirectorReducer.reduce(state: state, command: .undo(commandID: "u1")).state
        XCTAssertEqual(state.runtime.activeSectionID, "section_intro")
        XCTAssertEqual(state.runtime.revision, beforeUndoRevision + 1)
    }

    func testBlackoutsAreDistinctSafetyEffects() {
        let state = loadedState()
        let lighting = ShowDirectorReducer.reduce(state: state, command: .blackoutLighting(commandID: "bl"))
        let video = ShowDirectorReducer.reduce(state: state, command: .blackoutVideo(commandID: "bv"))
        XCTAssertTrue(lighting.effects.contains(.executeSafetyAction(
            commandID: "bl",
            action: .blackoutLighting(id: "safety_blackout_lighting")
        )))
        XCTAssertTrue(video.effects.contains(.executeSafetyAction(
            commandID: "bv",
            action: .blackoutVideo(id: "safety_blackout_video")
        )))
    }

    func testFirePresetNow_doesNotMutateAuthoredGraph() {
        let state = loadedState()
        let authored = state.graph
        let result = ShowDirectorReducer.reduce(
            state: state,
            command: .firePresetNow(commandID: "fp", presetID: "preset_purple_psychedelic")
        )
        XCTAssertEqual(result.disposition, .accepted)
        XCTAssertEqual(result.state.graph, authored)
        XCTAssertTrue(result.effects.contains(
            .executeCuePackage(commandID: "fp", cuePackageID: "cue_aurora_drop")
        ))
    }

    func testRejectedEmptyCommandID() {
        let result = ShowDirectorReducer.reduce(
            state: ShowDirectorReducerState(),
            command: .go(commandID: "  ")
        )
        XCTAssertEqual(result.disposition, .rejected(reason: "commandID must be non-empty."))
        XCTAssertEqual(result.state.runtime.revision, 0)
    }

    private func loadedState() -> ShowDirectorReducerState {
        ShowDirectorReducer.reduce(
            state: ShowDirectorReducerState(),
            command: .loadShow(commandID: "load", graph: ShowDirectorFixtures.demoGraph())
        ).state
    }
}
