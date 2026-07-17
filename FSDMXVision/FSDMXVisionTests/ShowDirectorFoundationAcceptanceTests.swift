import XCTest
@testable import FSDMXVision

final class ShowDirectorFoundationAcceptanceTests: XCTestCase {
    func testFoundationAcceptanceGate() async throws {
        let package = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: package) }

        // Build a minimal legacy package shell.
        let project = ShowProjectDocument(venue: VenueMetadata(name: "Hall"), show: ShowMetadata(title: "Demo"))
        try ShowProjectPackage.save(
            to: package,
            project: project,
            scenesData: try JSONEncoder().encode(SceneLibraryStore.Document(scenes: SceneBootstrap.starterScenes)),
            sceneControlsData: try JSONEncoder().encode(SceneControlStore.Document(states: [:])),
            dmxPatchData: try JSONEncoder().encode(DMXPatchDocument.default()),
            lightingCuesData: try JSONEncoder().encode(LightingCueDocument.default()),
            backdropCuesData: try JSONEncoder().encode(BackdropCueDocument.default()),
            modulationData: try JSONEncoder().encode(ModulationDocument()),
            stageLayoutData: try JSONEncoder().encode(StageLayoutDocument()),
            overlayCardsData: try JSONEncoder().encode(OverlayCardDocument.default())
        )

        let graph = ShowDirectorFixtures.demoGraph()
        try ShowDirectorPackageStore.ensureMediaLayout(in: package)
        try Data([0x00]).write(to: package.appendingPathComponent("Media/video/video_aurora_drop.mp4"))
        try ShowDirectorPackageStore.save(graph, to: package)

        let loaded = try ShowDirectorPackageStore.load(from: package)
        XCTAssertNotNil(loaded.graph)
        XCTAssertFalse(loaded.validation.hasErrors)

        let clock = ControllableShowDirectorClock()
        clock.setSleepHandler { seconds in
            if abs(seconds - 0.05) < 0.0001 {
                try? await Task.sleep(nanoseconds: 10_000_000)
            } else {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }

        let lighting = FakeShowEndpointAdapter(endpointKind: .lighting, clock: clock)
        await lighting.setDelaySeconds(1) // will time out on intro first action
        let palette = FakeShowEndpointAdapter(endpointKind: .palette, clock: clock)
        let video = FakeShowEndpointAdapter(endpointKind: .backdropVideo, clock: clock)
        let obs = FakeShowEndpointAdapter(endpointKind: .obs, clock: clock)

        let engine = ShowDirectorEngine(
            adapters: [lighting, palette, video, obs],
            clock: clock,
            packageRoot: package,
            actionTimeoutSeconds: 0.05
        )

        var stream = await engine.subscribe().makeAsyncIterator()
        _ = await stream.next() // unloaded

        let loadResult = await engine.submit(.loadShow(commandID: "cmd_load", graph: loaded.graph!))
        XCTAssertEqual(loadResult.disposition, .accepted)
        let readyState = await stream.next()
        XCTAssertEqual(readyState?.transport, .ready)

        _ = await engine.submit(.go(commandID: "cmd_go_intro"))
        _ = await engine.submit(.hold(commandID: "cmd_hold"))
        _ = await engine.submit(.resume(commandID: "cmd_resume"))
        _ = await engine.submit(.jumpToSection(commandID: "cmd_jump", sectionID: "section_drop"))
        _ = await engine.submit(.repeatSection(commandID: "cmd_repeat"))
        _ = await engine.submit(.undo(commandID: "cmd_undo"))

        let finalRuntime = await engine.runtimeState()
        XCTAssertGreaterThan(finalRuntime.revision, 1)
        XCTAssertEqual(finalRuntime.showID, "show_flyover_demo")

        let logs = try ShowDirectorExecutionLogStore.read(from: package)
        XCTAssertFalse(logs.entries.isEmpty)
        XCTAssertTrue(logs.entries.contains { entry in
            entry.results.contains { $0.status == .timedOut }
        })
        XCTAssertTrue(logs.entries.contains { entry in
            entry.results.contains { $0.status == .executed }
        })
    }
}
