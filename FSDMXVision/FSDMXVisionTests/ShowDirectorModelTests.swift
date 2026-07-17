import XCTest
@testable import FSDMXVision

final class ShowDirectorModelTests: XCTestCase {
    func testShowDocument_roundTrip_preservesStableIDsAndWireKeys() throws {
        let original = ShowDocument(
            id: "show_flyover_demo",
            metadata: ShowDirectorMetadata(name: "Flyover Demo Show", artist: "Flyover States"),
            defaultSetlistID: "setlist_main",
            setlistIDs: ["setlist_main"],
            songIDs: ["song_aurora"],
            cuePackageIDs: ["cue_aurora_intro", "cue_aurora_drop"],
            presetIDs: ["preset_purple_psychedelic"]
        )
        let data = try ShowDirectorJSON.makeEncoder().encode(original)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains("\"defaultSetlistId\""))
        XCTAssertTrue(json.contains("\"setlistIds\""))
        XCTAssertTrue(json.contains("\"cuePackageIds\""))
        let decoded = try ShowDirectorJSON.makeDecoder().decode(ShowDocument.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testSongScore_roundTrip_usesKeyWireSpelling() throws {
        let original = SongScore(
            id: "song_aurora",
            artist: "Flyover States",
            title: "Aurora",
            bpm: 124,
            musicalKey: "8A",
            sections: [
                SongSection(id: "section_intro", name: "Intro", type: .intro, cuePackageID: "cue_aurora_intro"),
                SongSection(id: "section_drop", name: "Drop", type: .drop, cuePackageID: "cue_aurora_drop"),
            ]
        )
        let data = try ShowDirectorJSON.makeEncoder().encode(original)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains("\"key\""))
        XCTAssertTrue(json.contains("\"cuePackageId\""))
        let decoded = try ShowDirectorJSON.makeDecoder().decode(SongScore.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testCuePackage_roundTrip_typedActions() throws {
        let original = CuePackage(
            id: "cue_aurora_drop",
            name: "Aurora Drop",
            actions: [
                .recallLightingScene(id: "action_light_drop", sceneID: "lighting_gold_white_full", fadeMilliseconds: 250),
                .applyPalette(id: "action_palette_drop", paletteID: "palette_cosmic_violet", fadeMilliseconds: 500),
                .playBackdropClip(id: "action_video_drop", clipID: "video_aurora_drop", transition: "flashDissolve", loop: true),
                .addOBSMarker(id: "action_obs_marker", label: "Aurora - Drop"),
            ]
        )
        let data = try ShowDirectorJSON.makeEncoder().encode(original)
        let decoded = try ShowDirectorJSON.makeDecoder().decode(CuePackage.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testEndpointAction_unknownCombination_throwsUsefulError() {
        let json = Data(#"{"id":"a1","endpoint":"camera","type":"recallPreset"}"#.utf8)
        XCTAssertThrowsError(try ShowDirectorJSON.makeDecoder().decode(EndpointAction.self, from: json)) { error in
            let message = String(describing: error)
            XCTAssertTrue(message.contains("camera") || message.contains("Unsupported"), message)
        }
    }

    func testStableID_validation() {
        XCTAssertTrue(ShowDirectorStableID.isValid("show_flyover_demo"))
        XCTAssertTrue(ShowDirectorStableID.isValid("a"))
        XCTAssertFalse(ShowDirectorStableID.isValid(""))
        XCTAssertFalse(ShowDirectorStableID.isValid("."))
        XCTAssertFalse(ShowDirectorStableID.isValid(".."))
        XCTAssertFalse(ShowDirectorStableID.isValid("bad/id"))
        XCTAssertFalse(ShowDirectorStableID.isValid("has space"))
    }

    func testExecutionLogEntry_roundTrip() throws {
        let entry = ExecutionLogEntry(
            id: "log_000012",
            timestamp: ISO8601DateFormatter().date(from: "2026-07-17T00:15:42Z")!,
            commandID: "cmd_2026_0001",
            cuePackageID: "cue_aurora_drop",
            results: [
                EndpointActionResult(
                    actionID: "action_light_drop",
                    endpoint: .lighting,
                    status: .executed,
                    durationMilliseconds: 41
                ),
            ],
            runtimeRevisionBefore: 42,
            runtimeRevisionAfter: 43
        )
        let data = try ShowDirectorJSON.makeCompactEncoder().encode(entry)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains("\"commandId\""))
        XCTAssertTrue(json.contains("\"durationMs\""))
        let decoded = try ShowDirectorJSON.makeDecoder().decode(ExecutionLogEntry.self, from: data)
        XCTAssertEqual(decoded, entry)
    }
}
