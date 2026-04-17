import XCTest
@testable import CosmicVisualizer

final class DMXOutputServiceTests: XCTestCase {
    func testBuildUniverse_setsSceneAndKnobs() {
        let model = AppModel()
        model.sceneManager.scenes = [
            VisualizationScene(name: "A", fractalMode: "julia", liquidLightEnabled: true),
            VisualizationScene(name: "B", fractalMode: "julia", liquidLightEnabled: true),
        ]
        model.sceneManager.currentIndex = 1
        model.syncRendererFromScene()
        model.applyRemoteCommand(RemoteControlCommand(type: "SetFractalZoom", fractalZoom: 1.5))
        model.applyRemoteCommand(RemoteControlCommand(type: "SetLiquidTurbulence", liquidTurbulence: 1.25))
        model.applyRemoteCommand(RemoteControlCommand(type: "SetCompositeBlend", compositeBlend: 0.8))
        var smooth: [UUID: Float] = [:]
        let u = model.buildDMXUniverse(time: 0, lastSmoothed: &smooth)
        XCTAssertEqual(u.count, 512)
        XCTAssertEqual(u[0], 1)
        XCTAssertGreaterThan(u[1], 0)
    }

    func testSimulatedDMXTransport_producesSnapshot() throws {
        let model = AppModel()
        var settings = model.remoteSettings
        settings.dmxOutputEnabled = true
        settings.dmxOutputMode = "simulated"
        model.remoteSettings = settings
        let exp = expectation(description: "simulation tick")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if let snap = model.dmxSimulationSnapshot() {
                XCTAssertEqual(snap.mode, "simulated")
                XCTAssertEqual(snap.universe.count, 512)
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 1.0)
    }

    func testCuratedCatalog_buildsAndTagsFogEntries() throws {
        let json = """
        {
          "manufacturers": {"adj":"ADJ", "antari":"Antari"},
          "fixtures": {
            "adj/mega-par-profile": {"name":"Mega Par Profile","categories":["Color Changer"]},
            "antari/hz-500": {"name":"HZ-500 Hazer","categories":["Effect"]}
          }
        }
        """.data(using: .utf8)!
        let cache = try OFLFixtureImportService.buildCuratedCatalog(from: json, limitPerManufacturer: 20)
        XCTAssertFalse(cache.entries.isEmpty)
        XCTAssertTrue(cache.entries.contains(where: { $0.fixtureSlug == "hz-500" && $0.isFogRelated }))
    }
}
