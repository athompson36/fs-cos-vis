import XCTest
@testable import FSDMXVision

final class ShowDirectorEngineTests: XCTestCase {
    func testDuplicateCommandID_executesOnce() async {
        let lighting = FakeShowEndpointAdapter(endpointKind: .lighting)
        let palette = FakeShowEndpointAdapter(endpointKind: .palette)
        let engine = ShowDirectorEngine(adapters: [lighting, palette])
        _ = await engine.submit(.loadShow(commandID: "load", graph: ShowDirectorFixtures.demoGraph()))
        let first = await engine.submit(.go(commandID: "go1"))
        let second = await engine.submit(.go(commandID: "go1"))
        XCTAssertFalse(first.duplicated)
        XCTAssertTrue(second.duplicated)
        let lightingCalls = await lighting.executeCalls
        XCTAssertEqual(lightingCalls.count, 1)
    }

    func testActionOrderIsDeterministicAndPartialFailureContinues() async {
        let lighting = FakeShowEndpointAdapter(endpointKind: .lighting)
        let palette = FakeShowEndpointAdapter(endpointKind: .palette)
        let video = FakeShowEndpointAdapter(endpointKind: .backdropVideo)
        let obs = FakeShowEndpointAdapter(endpointKind: .obs)
        await obs.setExecutionStatus(.failed, message: "OBS WebSocket disconnected")

        let package = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: package) }
        try! ShowDirectorPackageStore.ensureMediaLayout(in: package)
        try! ShowDirectorPackageStore.save(ShowDirectorFixtures.demoGraph(), to: package)

        let engine = ShowDirectorEngine(
            adapters: [lighting, palette, video, obs],
            packageRoot: package
        )
        _ = await engine.submit(.loadShow(commandID: "load", graph: ShowDirectorFixtures.demoGraph()))
        _ = await engine.submit(.go(commandID: "go1"))
        _ = await engine.submit(.go(commandID: "go2"))

        let lightingIDs = await lighting.executeCalls.map(\.id)
        let paletteIDs = await palette.executeCalls.map(\.id)
        let videoIDs = await video.executeCalls.map(\.id)
        let obsIDs = await obs.executeCalls.map(\.id)
        XCTAssertEqual(lightingIDs, ["action_light_intro", "action_light_drop"])
        XCTAssertEqual(paletteIDs, ["action_palette_intro", "action_palette_drop"])
        XCTAssertEqual(videoIDs, ["action_video_drop"])
        XCTAssertEqual(obsIDs, ["action_obs_marker"])

        let logs = try! ShowDirectorExecutionLogStore.read(from: package)
        XCTAssertEqual(logs.entries.count, 2)
        let dropLog = logs.entries[1]
        XCTAssertEqual(dropLog.results.map(\.actionID), [
            "action_light_drop",
            "action_palette_drop",
            "action_video_drop",
            "action_obs_marker",
        ])
        XCTAssertEqual(dropLog.results.last?.status, .failed)
    }

    func testTimeoutIsolatesAction() async {
        let clock = ControllableShowDirectorClock()
        clock.setSleepHandler { seconds in
            if abs(seconds - 0.05) < 0.0001 {
                try? await Task.sleep(nanoseconds: 10_000_000)
            } else {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
        let lighting = FakeShowEndpointAdapter(endpointKind: .lighting, clock: clock)
        await lighting.setDelaySeconds(1)
        let palette = FakeShowEndpointAdapter(endpointKind: .palette, clock: clock)

        let package = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: package) }
        try! ShowDirectorPackageStore.ensureMediaLayout(in: package)
        try! ShowDirectorPackageStore.save(ShowDirectorFixtures.demoGraph(), to: package)

        let engine = ShowDirectorEngine(
            adapters: [lighting, palette],
            clock: clock,
            packageRoot: package,
            actionTimeoutSeconds: 0.05
        )
        _ = await engine.submit(.loadShow(commandID: "load", graph: ShowDirectorFixtures.demoGraph()))
        _ = await engine.submit(.go(commandID: "go1"))

        let logs = try! ShowDirectorExecutionLogStore.read(from: package)
        XCTAssertEqual(logs.entries.count, 1)
        XCTAssertEqual(logs.entries[0].results.first?.status, .timedOut)
        XCTAssertEqual(logs.entries[0].results.last?.status, .executed)
        let paletteCalls = await palette.executeCalls
        XCTAssertEqual(paletteCalls.count, 1)
    }

    func testStateStreamYieldsInitialAndUpdates() async {
        let engine = ShowDirectorEngine(adapters: [])
        let stream = await engine.subscribe()
        var iterator = stream.makeAsyncIterator()
        let initial = await iterator.next()
        XCTAssertEqual(initial?.transport, .unloaded)

        _ = await engine.submit(.loadShow(commandID: "load", graph: ShowDirectorFixtures.demoGraph()))
        let updated = await iterator.next()
        XCTAssertEqual(updated?.transport, .ready)
        XCTAssertEqual(updated?.revision, 1)
    }

    func testConcurrentGO_serializes() async {
        let lighting = FakeShowEndpointAdapter(endpointKind: .lighting)
        let palette = FakeShowEndpointAdapter(endpointKind: .palette)
        let engine = ShowDirectorEngine(adapters: [lighting, palette])
        _ = await engine.submit(.loadShow(commandID: "load", graph: ShowDirectorFixtures.demoGraph()))

        async let a = engine.submit(.go(commandID: "goA"))
        async let b = engine.submit(.go(commandID: "goB"))
        _ = await (a, b)

        let runtime = await engine.runtimeState()
        XCTAssertEqual(runtime.activeSectionID, "section_drop")
        let lightingCalls = await lighting.executeCalls
        XCTAssertEqual(lightingCalls.count, 2)
    }
}
