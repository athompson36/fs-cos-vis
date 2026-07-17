import XCTest
@testable import FSDMXVision

@MainActor
final class ShowDirectorRuntimeLifecycleTests: XCTestCase {
    func testConfigureValidGraph_transitionsToReadyAndInstallsEngine() async {
        let model = AppModel()
        let graph = ShowDirectorFixtures.demoGraph()
        let package = temporaryPackageRoot()
        defer { try? FileManager.default.removeItem(at: package) }

        model.configureShowDirectorRuntime(graph: graph, packageRoot: package)
        await waitUntilRuntimeSettled(model)

        XCTAssertEqual(model.showDirectorRuntimeStatus, .ready)
        XCTAssertNotNil(model.showDirectorEngine)
        let runtime = await model.showDirectorEngine!.runtimeState()
        XCTAssertEqual(runtime.showID, graph.show.id)
    }

    func testConfigureNilGraph_yieldsUnconfiguredAndClearsEngine() async {
        let model = AppModel()
        let graph = ShowDirectorFixtures.demoGraph()
        let package = temporaryPackageRoot()
        defer { try? FileManager.default.removeItem(at: package) }

        model.configureShowDirectorRuntime(graph: graph, packageRoot: package)
        await waitUntilRuntimeSettled(model)
        XCTAssertEqual(model.showDirectorRuntimeStatus, .ready)
        XCTAssertNotNil(model.showDirectorEngine)

        model.configureShowDirectorRuntime(graph: nil, packageRoot: package)
        await waitUntilRuntimeSettled(model)

        XCTAssertEqual(model.showDirectorRuntimeStatus, .unconfigured)
        XCTAssertNil(model.showDirectorEngine)
    }

    func testConfigureRejectedLoad_yieldsFailedAndClearsEngine() async {
        let model = AppModel()
        let package = temporaryPackageRoot()
        defer { try? FileManager.default.removeItem(at: package) }
        let rejectedGraph = ShowDirectorFixtures.demoGraphMutating { graph in
            var setlist = graph.setlistsByID[graph.show.defaultSetlistID]!
            setlist.items = []
            graph.setlistsByID[setlist.id] = setlist
        }

        model.configureShowDirectorRuntime(graph: rejectedGraph, packageRoot: package)
        await waitUntilRuntimeSettled(model)

        guard case .failed(let message) = model.showDirectorRuntimeStatus else {
            return XCTFail("Expected failed status, got \(model.showDirectorRuntimeStatus)")
        }
        XCTAssertEqual(message, "Show graph is missing a default setlist item/section.")
        XCTAssertNil(model.showDirectorEngine)
    }

    func testStartingConfigurationBBeforeDelayedACompletes_installsOnlyB() async {
        let model = AppModel()
        let package = temporaryPackageRoot()
        defer { try? FileManager.default.removeItem(at: package) }

        let graphA = ShowDirectorFixtures.demoGraphMutating { graph in
            graph.show.id = "show_config_a"
            graph.show.metadata.name = "Config A"
        }
        let graphB = ShowDirectorFixtures.demoGraphMutating { graph in
            graph.show.id = "show_config_b"
            graph.show.metadata.name = "Config B"
        }

        let gate = LoaderGate()
        let loaderState = LoaderCallState()
        model.showDirectorGraphLoader = { engine, graph, commandID in
            let ordinal = await loaderState.beginCall(commandID: commandID, showID: graph.show.id)
            if ordinal == 1 {
                await gate.wait()
            }
            let result = await engine.submit(.loadShow(commandID: commandID, graph: graph))
            await loaderState.finishCall(commandID: commandID)
            return result
        }

        model.configureShowDirectorRuntime(graph: graphA, packageRoot: package)
        await loaderState.waitUntilCallCount(1)

        model.configureShowDirectorRuntime(graph: graphB, packageRoot: package)
        await waitUntilRuntimeSettled(model)

        XCTAssertEqual(model.showDirectorRuntimeStatus, .ready)
        let runtimeBeforeRelease = await model.showDirectorEngine!.runtimeState()
        XCTAssertEqual(runtimeBeforeRelease.showID, "show_config_b")

        await gate.release()
        await loaderState.waitUntilFinishedCount(2)

        XCTAssertEqual(model.showDirectorRuntimeStatus, .ready)
        let runtimeAfterRelease = await model.showDirectorEngine!.runtimeState()
        XCTAssertEqual(runtimeAfterRelease.showID, "show_config_b")
        let calls = await loaderState.snapshot()
        XCTAssertEqual(calls.startedShowIDs, ["show_config_a", "show_config_b"])
        XCTAssertEqual(calls.finishedCommandIDs.count, 2)
    }

    func testReplaceShowDirectorGraph_configuresRuntime() async {
        let model = AppModel()

        model.replaceShowDirectorGraph(ShowDirectorFixtures.demoGraph())
        await waitUntilRuntimeSettled(model)

        XCTAssertEqual(model.showDirectorRuntimeStatus, .ready)
        XCTAssertNotNil(model.showDirectorEngine)
        XCTAssertEqual(model.showDirectorGraph?.show.id, "show_flyover_demo")

        model.replaceShowDirectorGraph(nil)
        await waitUntilRuntimeSettled(model)
        XCTAssertEqual(model.showDirectorRuntimeStatus, .unconfigured)
        XCTAssertNil(model.showDirectorEngine)
        XCTAssertNil(model.showDirectorGraph)
    }

    // MARK: - Helpers

    private func temporaryPackageRoot() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sd-runtime-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func waitUntilRuntimeSettled(_ model: AppModel) async {
        for _ in 0 ..< 500 {
            if model.showDirectorRuntimeStatus != .loading {
                return
            }
            await Task.yield()
            try? await Task.sleep(nanoseconds: 2_000_000)
        }
        XCTFail("Timed out waiting for Show Director runtime to leave loading")
    }
}

private actor LoaderCallState {
    private var startedShowIDs: [String] = []
    private var finishedCommandIDs: [String] = []
    private var callCount = 0

    struct Snapshot {
        var startedShowIDs: [String]
        var finishedCommandIDs: [String]
    }

    func beginCall(commandID: String, showID: String) -> Int {
        _ = commandID
        callCount += 1
        startedShowIDs.append(showID)
        return callCount
    }

    func finishCall(commandID: String) {
        finishedCommandIDs.append(commandID)
    }

    func waitUntilCallCount(_ expected: Int) async {
        for _ in 0 ..< 500 {
            if callCount >= expected { return }
            try? await Task.sleep(nanoseconds: 2_000_000)
        }
    }

    func waitUntilFinishedCount(_ expected: Int) async {
        for _ in 0 ..< 500 {
            if finishedCommandIDs.count >= expected { return }
            try? await Task.sleep(nanoseconds: 2_000_000)
        }
    }

    func snapshot() -> Snapshot {
        Snapshot(startedShowIDs: startedShowIDs, finishedCommandIDs: finishedCommandIDs)
    }
}

private actor LoaderGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isReleased = false

    func wait() async {
        if isReleased { return }
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func release() {
        isReleased = true
        let pending = continuation
        continuation = nil
        pending?.resume()
    }
}
