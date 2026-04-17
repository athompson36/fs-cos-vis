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
}
