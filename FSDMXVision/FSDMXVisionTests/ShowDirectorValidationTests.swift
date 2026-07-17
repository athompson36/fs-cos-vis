import XCTest
@testable import FSDMXVision

final class ShowDirectorValidationTests: XCTestCase {
    func testValidate_missingCueReference_isError() {
        let graph = ShowDirectorFixtures.demoGraphMutating { graph in
            graph.cuePackagesByID.removeValue(forKey: "cue_aurora_drop")
            graph.show.cuePackageIDs.removeAll { $0 == "cue_aurora_drop" }
        }
        let result = ShowDirectorValidator.validate(graph)
        XCTAssertTrue(result.hasErrors)
        XCTAssertTrue(result.errors.contains { $0.code == "missing_cue_package_reference" })
    }

    func testValidate_duplicateActionIDs_areDeterministic() {
        let graph = ShowDirectorFixtures.demoGraphMutating { graph in
            var cue = graph.cuePackagesByID["cue_aurora_drop"]!
            cue.actions = [
                .blackoutLighting(id: "dup"),
                .blackoutVideo(id: "dup"),
            ]
            graph.cuePackagesByID["cue_aurora_drop"] = cue
        }
        let result = ShowDirectorValidator.validate(graph)
        let duplicates = result.errors.filter { $0.code == "duplicate_action_id" }
        XCTAssertEqual(duplicates.count, 1)
        XCTAssertEqual(duplicates[0].path, "cue-packages/cue_aurora_drop.actions[1]")
    }

    func testValidate_missingMedia_isWarningOnly() {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let result = ShowDirectorValidator.validate(ShowDirectorFixtures.demoGraph(), packageRoot: temp)
        XCTAssertFalse(result.hasErrors)
        XCTAssertTrue(result.warnings.contains { $0.code == "missing_media" })
    }

    func testValidate_absoluteMediaPath_isError() {
        // Absolute paths are checked via the clip path construction helper through validator media check.
        // Craft an action whose clipID would produce a bad path by validating a crafted relative path indirectly:
        // The validator currently synthesizes Media/video/<clipId>.mp4; escaping is tested via package-relative rules
        // when clipID contains `..`.
        let graph = ShowDirectorFixtures.demoGraphMutating { graph in
            var cue = graph.cuePackagesByID["cue_aurora_drop"]!
            cue.actions = [
                .playBackdropClip(id: "bad", clipID: "../escape", transition: "cut", loop: false),
            ]
            graph.cuePackagesByID["cue_aurora_drop"] = cue
        }
        let result = ShowDirectorValidator.validate(graph, packageRoot: FileManager.default.temporaryDirectory)
        XCTAssertTrue(result.errors.contains { $0.code == "escaping_media_path" })
    }

    func testMigrator_passThroughIsIdempotent() throws {
        let cue = ShowDirectorFixtures.demoGraph().cuePackagesByID["cue_aurora_drop"]!
        let data = try ShowDirectorJSON.makeEncoder().encode(cue)
        let once = try ShowDirectorMigrator.migrateDocumentData(data, kind: .cuePackage)
        let twice = try ShowDirectorMigrator.migrateDocumentData(once, kind: .cuePackage)
        let decodedOnce = try ShowDirectorJSON.makeDecoder().decode(CuePackage.self, from: once)
        let decodedTwice = try ShowDirectorJSON.makeDecoder().decode(CuePackage.self, from: twice)
        XCTAssertEqual(decodedOnce, cue)
        XCTAssertEqual(decodedTwice, cue)
    }

    func testMigrator_rejectsFutureSchemaVersion() throws {
        var cue = ShowDirectorFixtures.demoGraph().cuePackagesByID["cue_aurora_drop"]!
        cue.schemaVersion = 99
        let data = try ShowDirectorJSON.makeEncoder().encode(cue)
        XCTAssertThrowsError(try ShowDirectorMigrator.migrateDocumentData(data, kind: .cuePackage)) { error in
            guard case ShowDirectorMigrationError.unsupportedFutureSchemaVersion = error else {
                return XCTFail("unexpected \(error)")
            }
        }
    }
}

enum ShowDirectorFixtures {
    static func demoGraph() -> ShowDirectorGraph {
        let intro = CuePackage(
            id: "cue_aurora_intro",
            name: "Aurora Intro",
            actions: [
                .recallLightingScene(id: "action_light_intro", sceneID: "lighting_soft_blue", fadeMilliseconds: 500),
                .applyPalette(id: "action_palette_intro", paletteID: "palette_cosmic_blue", fadeMilliseconds: 500),
            ]
        )
        let drop = CuePackage(
            id: "cue_aurora_drop",
            name: "Aurora Drop",
            actions: [
                .recallLightingScene(id: "action_light_drop", sceneID: "lighting_gold_white_full", fadeMilliseconds: 250),
                .applyPalette(id: "action_palette_drop", paletteID: "palette_cosmic_violet", fadeMilliseconds: 500),
                .playBackdropClip(id: "action_video_drop", clipID: "video_aurora_drop", transition: "flashDissolve", loop: true),
                .addOBSMarker(id: "action_obs_marker", label: "Aurora - Drop"),
            ]
        )
        let song = SongScore(
            id: "song_aurora",
            artist: "Flyover States",
            title: "Aurora",
            bpm: 124,
            musicalKey: "8A",
            sections: [
                SongSection(id: "section_intro", name: "Intro", type: .intro, cuePackageID: intro.id),
                SongSection(id: "section_drop", name: "Drop", type: .drop, cuePackageID: drop.id),
            ]
        )
        let setlist = Setlist(
            id: "setlist_main",
            name: "Main Set",
            items: [
                SetlistItem(id: "item_001", songScoreID: song.id, label: "Aurora"),
            ]
        )
        let preset = ShowPreset(
            id: "preset_purple_psychedelic",
            name: "Purple Psychedelic",
            cuePackageID: drop.id
        )
        let show = ShowDocument(
            id: "show_flyover_demo",
            metadata: ShowDirectorMetadata(name: "Flyover Demo Show", artist: "Flyover States"),
            defaultSetlistID: setlist.id,
            setlistIDs: [setlist.id],
            songIDs: [song.id],
            cuePackageIDs: [intro.id, drop.id],
            presetIDs: [preset.id]
        )
        return ShowDirectorGraph(
            show: show,
            setlistsByID: [setlist.id: setlist],
            songsByID: [song.id: song],
            cuePackagesByID: [intro.id: intro, drop.id: drop],
            presetsByID: [preset.id: preset]
        )
    }

    static func demoGraphMutating(_ mutate: (inout ShowDirectorGraph) -> Void) -> ShowDirectorGraph {
        var graph = demoGraph()
        mutate(&graph)
        return graph
    }
}
