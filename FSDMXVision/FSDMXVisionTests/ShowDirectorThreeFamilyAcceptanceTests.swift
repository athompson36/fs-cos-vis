import Foundation
import XCTest
@testable import FSDMXVision

@MainActor
private final class AcceptanceVisualSceneController: VisualSceneControlling {
    var ids: [UUID]
    var activeID: UUID?
    var verificationOverrideID: UUID?

    init(ids: [UUID], activeID: UUID? = nil) {
        self.ids = ids
        self.activeID = activeID
    }

    func visualSceneIDs() -> [UUID] { ids }
    func activeVisualSceneID() -> UUID? { verificationOverrideID ?? activeID }
    func recallVisualScene(id: UUID) throws {
        activeID = id
    }
}

@MainActor
private final class AcceptancePaletteController: PaletteControlling {
    var ids: [UUID]
    var activeID: UUID?
    var verificationOverrideID: UUID?

    init(ids: [UUID], activeID: UUID? = nil) {
        self.ids = ids
        self.activeID = activeID
    }

    func paletteIDs() -> [UUID] { ids }
    func activePaletteID() -> UUID? { verificationOverrideID ?? activeID }
    func selectPalette(id: UUID) throws {
        activeID = id
    }
}

@MainActor
private final class AcceptanceLightingCueController: LightingCueControlling {
    var ids: [UUID]
    var activeID: UUID?
    var verificationOverrideID: UUID?
    var fadeSecondsByID: [UUID: Double]

    init(ids: [UUID], activeID: UUID? = nil, fadeSecondsByID: [UUID: Double] = [:]) {
        self.ids = ids
        self.activeID = activeID
        self.fadeSecondsByID = fadeSecondsByID
    }

    func lightingCueIDs() -> [UUID] { ids }
    func activeLightingCueID() -> UUID? { verificationOverrideID ?? activeID }
    func recallLightingCue(id: UUID) throws {
        activeID = id
    }
    func lightingCueFadeSeconds(id: UUID) -> Double? { fadeSecondsByID[id] }
}

@MainActor
final class ShowDirectorThreeFamilyAcceptanceTests: XCTestCase {
    func testThreeFamilyCueExecutesThroughRealAdapters() async throws {
        let sceneID = UUID()
        let paletteID = UUID()
        let lightingCueID = UUID()

        let visualController = AcceptanceVisualSceneController(ids: [sceneID])
        let paletteController = AcceptancePaletteController(ids: [paletteID])
        let lightingController = AcceptanceLightingCueController(
            ids: [lightingCueID],
            fadeSecondsByID: [lightingCueID: 1.0]
        )

        let visualAdapter = VisualSceneEndpointAdapter(controller: visualController)
        let paletteAdapter = PaletteEndpointAdapter(controller: paletteController)
        let lightingAdapter = LightingCueEndpointAdapter(controller: lightingController)

        let package = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: package) }
        try ShowDirectorPackageStore.ensureMediaLayout(in: package)

        let graph = Self.makeThreeFamilyGraph(
            sceneID: sceneID,
            paletteID: paletteID,
            lightingCueID: lightingCueID
        )
        try ShowDirectorPackageStore.save(graph, to: package)

        let engine = ShowDirectorEngine(
            adapters: [visualAdapter, paletteAdapter, lightingAdapter],
            packageRoot: package
        )

        let loadResult = await engine.submit(.loadShow(commandID: "cmd_load_three_family", graph: graph))
        XCTAssertEqual(loadResult.disposition, .accepted)
        let revisionAfterLoad = await engine.runtimeState().revision

        let goResult = await engine.submit(.go(commandID: "cmd_go_three_family"))
        XCTAssertEqual(goResult.disposition, .accepted)

        XCTAssertEqual(visualController.activeID, sceneID)
        XCTAssertEqual(paletteController.activeID, paletteID)
        XCTAssertEqual(lightingController.activeID, lightingCueID)

        let logs = try ShowDirectorExecutionLogStore.read(from: package)
        XCTAssertEqual(logs.entries.count, 1)
        let entry = try XCTUnwrap(logs.entries.first)
        XCTAssertEqual(entry.cuePackageID, "cue_three_family")
        XCTAssertEqual(entry.results.map(\.actionID), [
            "action_visual",
            "action_palette",
            "action_lighting",
        ])
        XCTAssertEqual(entry.results.map(\.status), [
            .executed,
            .executed,
            .executed,
        ])

        let revisionAfterGo = await engine.runtimeState().revision
        XCTAssertGreaterThan(revisionAfterGo, revisionAfterLoad)

        let visualHealth = await visualAdapter.currentHealth()
        let paletteHealth = await paletteAdapter.currentHealth()
        let lightingHealth = await lightingAdapter.currentHealth()
        XCTAssertEqual(visualHealth.status, .available)
        XCTAssertEqual(paletteHealth.status, .available)
        XCTAssertEqual(lightingHealth.status, .available)
    }

    func testPaletteVerificationFailureDoesNotBlockLighting() async throws {
        let sceneID = UUID()
        let paletteID = UUID()
        let lightingCueID = UUID()

        let visualController = AcceptanceVisualSceneController(ids: [sceneID])
        let paletteController = AcceptancePaletteController(ids: [paletteID])
        paletteController.verificationOverrideID = UUID()
        let lightingController = AcceptanceLightingCueController(
            ids: [lightingCueID],
            fadeSecondsByID: [lightingCueID: 1.0]
        )

        let visualAdapter = VisualSceneEndpointAdapter(controller: visualController)
        let paletteAdapter = PaletteEndpointAdapter(controller: paletteController)
        let lightingAdapter = LightingCueEndpointAdapter(controller: lightingController)

        let package = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: package) }
        try ShowDirectorPackageStore.ensureMediaLayout(in: package)

        let graph = Self.makeThreeFamilyGraph(
            sceneID: sceneID,
            paletteID: paletteID,
            lightingCueID: lightingCueID
        )
        try ShowDirectorPackageStore.save(graph, to: package)

        let engine = ShowDirectorEngine(
            adapters: [visualAdapter, paletteAdapter, lightingAdapter],
            packageRoot: package
        )

        _ = await engine.submit(.loadShow(commandID: "cmd_load_partial", graph: graph))
        _ = await engine.submit(.go(commandID: "cmd_go_partial"))

        XCTAssertEqual(visualController.activeID, sceneID)
        XCTAssertEqual(lightingController.activeID, lightingCueID)

        let logs = try ShowDirectorExecutionLogStore.read(from: package)
        XCTAssertEqual(logs.entries.count, 1)
        let entry = try XCTUnwrap(logs.entries.first)
        XCTAssertEqual(entry.results.map(\.status), [
            .executed,
            .failed,
            .executed,
        ])
    }

    private static func makeThreeFamilyGraph(
        sceneID: UUID,
        paletteID: UUID,
        lightingCueID: UUID
    ) -> ShowDirectorGraph {
        let cue = CuePackage(
            id: "cue_three_family",
            name: "Three Family",
            actions: [
                .recallVisualScene(id: "action_visual", sceneID: sceneID.uuidString, fadeMilliseconds: 500),
                .applyPalette(id: "action_palette", paletteID: paletteID.uuidString, fadeMilliseconds: 500),
                .recallLightingCue(id: "action_lighting", cueID: lightingCueID.uuidString),
            ]
        )
        let song = SongScore(
            id: "song_three_family",
            artist: "Flyover States",
            title: "Three Family",
            sections: [
                SongSection(id: "section_main", name: "Main", type: .verse, cuePackageID: cue.id),
            ]
        )
        let setlist = Setlist(
            id: "setlist_three_family",
            name: "Three Family Set",
            items: [
                SetlistItem(id: "item_001", songScoreID: song.id, label: "Three Family"),
            ]
        )
        let show = ShowDocument(
            id: "show_three_family",
            metadata: ShowDirectorMetadata(name: "Three Family Show", artist: "Flyover States"),
            defaultSetlistID: setlist.id,
            setlistIDs: [setlist.id],
            songIDs: [song.id],
            cuePackageIDs: [cue.id],
            presetIDs: []
        )
        return ShowDirectorGraph(
            show: show,
            setlistsByID: [setlist.id: setlist],
            songsByID: [song.id: song],
            cuePackagesByID: [cue.id: cue],
            presetsByID: [:]
        )
    }
}
