import XCTest
@testable import FSDMXVision

final class ShowDirectorPackageStoreTests: XCTestCase {
    func testSaveLoad_roundTrip() throws {
        let package = try makeLegacyPackage()
        defer { try? FileManager.default.removeItem(at: package) }

        let graph = ShowDirectorFixtures.demoGraph()
        try ShowDirectorPackageStore.ensureMediaLayout(in: package)
        // Create media file so missing-media warning is absent for the clip path.
        let mediaURL = package
            .appendingPathComponent("Media/video/video_aurora_drop.mp4")
        try Data([0x00]).write(to: mediaURL)

        try ShowDirectorPackageStore.save(graph, to: package)
        let loaded = try ShowDirectorPackageStore.load(from: package)
        XCTAssertEqual(loaded.graph, graph)
        XCTAssertFalse(loaded.validation.hasErrors)

        XCTAssertTrue(FileManager.default.fileExists(
            atPath: package.appendingPathComponent("Media/video").path
        ))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: package.appendingPathComponent("Media/images").path
        ))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: package.appendingPathComponent("Media/overlays").path
        ))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: package.appendingPathComponent("show-director/setlists/setlist_main.json").path
        ))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: package.appendingPathComponent("show-director/cue-packages/cue_aurora_drop.json").path
        ))
    }

    func testLegacyPackage_withoutShowDirector_loadsNilGraph() throws {
        let package = try makeLegacyPackage()
        defer { try? FileManager.default.removeItem(at: package) }
        let loaded = try ShowDirectorPackageStore.load(from: package)
        XCTAssertNil(loaded.graph)
        XCTAssertTrue(loaded.validation.issues.isEmpty)
    }

    func testDocumentIDMismatch_isRejected() throws {
        let package = try makeLegacyPackage()
        defer { try? FileManager.default.removeItem(at: package) }
        try ShowDirectorPackageStore.save(ShowDirectorFixtures.demoGraph(), to: package)

        let bad = package.appendingPathComponent("show-director/setlists/setlist_main.json")
        var setlist = ShowDirectorFixtures.demoGraph().setlistsByID["setlist_main"]!
        setlist.id = "setlist_other"
        try ShowDirectorJSON.makeEncoder().encode(setlist).write(to: bad, options: .atomic)

        XCTAssertThrowsError(try ShowDirectorPackageStore.load(from: package)) { error in
            guard case ShowDirectorPackageStoreError.documentIDMismatch = error else {
                return XCTFail("unexpected \(error)")
            }
        }
    }

    func testExecutionLog_appendAndRead_ignoresMalformedFinalLine() throws {
        let package = try makeLegacyPackage()
        defer { try? FileManager.default.removeItem(at: package) }
        try ShowDirectorPackageStore.save(ShowDirectorFixtures.demoGraph(), to: package)

        let entry = ExecutionLogEntry(
            id: "log_1",
            timestamp: ISO8601DateFormatter().date(from: "2026-07-17T00:15:42Z")!,
            commandID: "cmd_1",
            cuePackageID: "cue_aurora_intro",
            results: [],
            runtimeRevisionBefore: 1,
            runtimeRevisionAfter: 2
        )
        try ShowDirectorExecutionLogStore.append(entry, to: package)

        let url = ShowDirectorPackageLayout.executionLogURL(in: package)
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{not-json".utf8))
        try handle.close()

        let read = try ShowDirectorExecutionLogStore.read(from: package)
        XCTAssertEqual(read.entries, [entry])
        XCTAssertEqual(read.warnings.count, 1)
    }

    func testArchiveExportImport_preservesShowDirector() throws {
        let package = try makeLegacyPackage()
        defer { try? FileManager.default.removeItem(at: package) }
        try ShowDirectorPackageStore.ensureMediaLayout(in: package)
        try Data([0x00]).write(to: package.appendingPathComponent("Media/video/video_aurora_drop.mp4"))
        try ShowDirectorPackageStore.save(ShowDirectorFixtures.demoGraph(), to: package)

        let archive = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).cosmicshow.zip")
        let extract = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: archive)
            try? FileManager.default.removeItem(at: extract)
        }
        try ShowProjectPackage.exportArchive(from: package, to: archive)
        let imported = try ShowProjectPackage.importArchive(from: archive, to: extract)
        let loaded = try ShowDirectorPackageStore.load(from: imported)
        XCTAssertEqual(loaded.graph?.show.id, "show_flyover_demo")
    }

    private func makeLegacyPackage() throws -> URL {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let project = ShowProjectDocument(venue: VenueMetadata(name: "Hall"), show: ShowMetadata(title: "Night1"))
        let scenes = try JSONEncoder().encode(SceneLibraryStore.Document(scenes: SceneBootstrap.starterScenes))
        let controls = try JSONEncoder().encode(SceneControlStore.Document(states: [:]))
        let patch = try JSONEncoder().encode(DMXPatchDocument.default())
        let cues = try JSONEncoder().encode(LightingCueDocument.default())
        let backs = try JSONEncoder().encode(BackdropCueDocument.default())
        let mod = try JSONEncoder().encode(ModulationDocument())
        let stage = try JSONEncoder().encode(StageLayoutDocument())
        let cards = try JSONEncoder().encode(OverlayCardDocument.default())
        try ShowProjectPackage.save(
            to: tmp,
            project: project,
            scenesData: scenes,
            sceneControlsData: controls,
            dmxPatchData: patch,
            lightingCuesData: cues,
            backdropCuesData: backs,
            modulationData: mod,
            stageLayoutData: stage,
            overlayCardsData: cards
        )
        return tmp
    }
}
