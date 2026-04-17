import XCTest

@testable import CosmicVisualizer

class ShowProjectAndContextTests: XCTestCase {
    func testShowProjectPackageRoundTrip() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

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

        let loaded = try ShowProjectPackage.loadProject(from: tmp)
        XCTAssertEqual(loaded.venue.name, "Hall")
        XCTAssertEqual(loaded.show.title, "Night1")
        let cuesBack = try JSONDecoder().decode(LightingCueDocument.self, from: try ShowProjectPackage.loadLightingCues(from: tmp))
        XCTAssertFalse(cuesBack.cues.isEmpty)
    }

    func testLightingCueBookmarksDecodeV1() throws {
        let json = """
        {"version":1,"cues":[],"activeCueIndex":null}
        """
        let doc = try JSONDecoder().decode(LightingCueDocument.self, from: Data(json.utf8))
        XCTAssertTrue(doc.bookmarkedCueIds.isEmpty)
    }

    func testMachineContextSchemaRoundTrip() throws {
        let snap = ShowContextSnapshot(
            projectMeta: ShowProjectDocument(),
            dmxPatch: DMXPatchDocument.default(),
            lightingCues: LightingCueDocument.default(),
            backdropCues: BackdropCueDocument.default(),
            modulation: ModulationDocument.default(),
            stageLayout: StageLayoutDocument(),
            sceneIndex: 0,
            sceneName: "Test",
            sceneCount: 1,
            selectedPaletteID: nil,
            overlayEnabled: false,
            overlays: [],
            performanceFlags: MachinePerformanceFlags(
                lightingStripEnabled: true,
                backdropStripEnabled: false,
                hybridAIEnabled: false
            ),
            calibrationRelativePath: nil
        )
        let root = ShowContextGenerator.buildMachineRoot(from: snap)
        let data = try ShowContextGenerator.encodeMachineJSON(root: root)
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let decoded = try dec.decode(MachineContextRoot.self, from: data)
        XCTAssertEqual(decoded.schemaVersion, ShowContextGenerator.schemaVersion)
        XCTAssertEqual(decoded.lighting.cues.count, snap.lightingCues.cues.count)
    }

    func testShowProjectArchiveExportImportRoundTrip() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let packageFolder = tmp.appendingPathComponent("Demo Show", isDirectory: true)

        let project = ShowProjectDocument(venue: VenueMetadata(name: "Warehouse"), show: ShowMetadata(title: "Demo Show"))
        let scenes = try JSONEncoder().encode(SceneLibraryStore.Document(scenes: SceneBootstrap.starterScenes))
        let controls = try JSONEncoder().encode(SceneControlStore.Document(states: [:]))
        let patch = try JSONEncoder().encode(DMXPatchDocument.default())
        let cues = try JSONEncoder().encode(LightingCueDocument.default())
        let backs = try JSONEncoder().encode(BackdropCueDocument.default())
        let mod = try JSONEncoder().encode(ModulationDocument())
        let stage = try JSONEncoder().encode(StageLayoutDocument())
        let cards = try JSONEncoder().encode(OverlayCardDocument.default())
        try ShowProjectPackage.save(
            to: packageFolder,
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

        let archiveURL = tmp.appendingPathComponent("demo.cosmicshow.zip")
        try ShowProjectPackage.exportArchive(from: packageFolder, to: archiveURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: archiveURL.path))

        let extractRoot = tmp.appendingPathComponent("extracted", isDirectory: true)
        let importedPackage = try ShowProjectPackage.importArchive(from: archiveURL, to: extractRoot)
        let loaded = try ShowProjectPackage.loadProject(from: importedPackage)
        XCTAssertEqual(loaded.venue.name, "Warehouse")
        XCTAssertEqual(loaded.show.title, "Demo Show")
    }
}

/// Manual QA (hybrid AI off/on): verify context folder updates after DMX edits; Live Show strips with bookmarks;
/// project Save/Open; Settings LLM only fires when enabled and key present; calibration sweep requires camera permission.
