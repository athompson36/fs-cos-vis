import XCTest
@testable import CosmicVisualizer

final class ModelCodableTests: XCTestCase {
    func testVisualizationScene_roundTrip() throws {
        let id = UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!
        let palette = UUID(uuidString: "00000000-0000-0000-0000-0000000000BB")!
        let original = VisualizationScene(
            id: id,
            name: "Test",
            fractalMode: "julia",
            liquidLightEnabled: true,
            paletteID: palette,
            overlayIDs: []
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VisualizationScene.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testThemePalette_roundTrip() throws {
        let id = UUID(uuidString: "00000000-0000-0000-0000-0000000000CC")!
        let original = ThemePalette(
            id: id,
            name: "Nebula",
            primaryHex: "#110022",
            secondaryHex: "#330066",
            accentHex: "#00FFEE",
            glowHex: "#FF00AA"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ThemePalette.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testSceneEditState_layerControls_decodeLegacyMissingKeys() throws {
        let json = """
        {"layer":{"fractalZoom":1.2,"liquidTurbulence":0.9,"compositeBlend":0.5}}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SceneEditState.self, from: json)
        XCTAssertEqual(decoded.layer.fractalZoom, 1.2, accuracy: 0.001)
        XCTAssertEqual(decoded.layer.liquidFocus, 0.78, accuracy: 0.001)
        XCTAssertEqual(decoded.layer.fractalAppearance, 0, accuracy: 0.001)
    }

    func testOverlayAsset_roundTrip() throws {
        let id = UUID(uuidString: "00000000-0000-0000-0000-0000000000DD")!
        let original = OverlayAsset(id: id, name: "Logo", filePath: "/tmp/logo.png", opacity: 0.8, blendMode: "screen")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OverlayAsset.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
