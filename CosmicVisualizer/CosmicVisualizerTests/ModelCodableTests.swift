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

    func testSceneEditState_dropperLayers_decodeLegacyDropperKeys() throws {
        let json = """
        {"layer":{"dropperColorR":0.9,"dropperColorG":0.3,"dropperColorB":0.1,"dropperViscosity":0.72}}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SceneEditState.self, from: json)
        XCTAssertEqual(decoded.layer.liquidDropperLayers.count, 3)
        XCTAssertEqual(decoded.layer.liquidDropperLayers[0].colorR, 0.9, accuracy: 0.001)
        XCTAssertEqual(decoded.layer.liquidDropperLayers[0].colorG, 0.3, accuracy: 0.001)
        XCTAssertEqual(decoded.layer.liquidDropperLayers[0].colorB, 0.1, accuracy: 0.001)
        XCTAssertEqual(decoded.layer.liquidDropperLayers[0].viscosity, 0.72, accuracy: 0.001)
    }

    func testOverlayAsset_roundTrip() throws {
        let id = UUID(uuidString: "00000000-0000-0000-0000-0000000000DD")!
        let original = OverlayAsset(id: id, name: "Logo", filePath: "/tmp/logo.png", opacity: 0.8, blendMode: "screen")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OverlayAsset.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testLightingCue_hazePresetRoundTrip() throws {
        let hid = UUID(uuidString: "00000000-0000-0000-0000-0000000000EE")!
        let preset = HazeLearnPreset(
            steadyHazeDMX: 140,
            riseTimeSeconds: 4.2,
            dissipationHalfLifeSeconds: 12.5,
            learnedAt: Date(timeIntervalSince1970: 1_700_000_000),
            cameraBaselineLuma: 0.22,
            cameraPeakLuma: 0.41,
            targetInstanceID: hid
        )
        let original = LightingCue(
            name: "Haze wash",
            fadeSeconds: 2,
            channelValues: [ChannelValue(channel: 5, value: 10)],
            hazeLearnPreset: preset,
            autoApplyHazeEnvelope: true
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LightingCue.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testLightingCue_decodeLegacyWithoutHazeKeys() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000001","name":"Legacy","fadeSeconds":1,"channelValues":[]}
        """.data(using: .utf8)!
        let cue = try JSONDecoder().decode(LightingCue.self, from: json)
        XCTAssertNil(cue.hazeLearnPreset)
        XCTAssertFalse(cue.autoApplyHazeEnvelope)
    }

    func testLightingCueDocument_decodeLegacyWithoutBookmarkMetadata() throws {
        let json = """
        {
          "version": 1,
          "cues": [
            {"id":"00000000-0000-0000-0000-000000000101","name":"Legacy Cue","fadeSeconds":1,"channelValues":[]}
          ],
          "activeCueIndex": 0,
          "bookmarkedCueIds": ["00000000-0000-0000-0000-000000000101"]
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(LightingCueDocument.self, from: json)
        XCTAssertEqual(decoded.bookmarkedCueIds.count, 1)
        XCTAssertTrue(decoded.bookmarkMetadataByCueID.isEmpty)
    }

    func testOverlayCardDocument_decodeLegacyWithoutMetadataAndTimeout() throws {
        let json = """
        {
          "version": 1,
          "name": "Legacy Overlay",
          "shapes": [
            {"id":"00000000-0000-0000-0000-000000000201","kind":"rect","frame":{"x":0.1,"y":0.1,"width":0.4,"height":0.2},"fillColorRGBA":[1,1,1,1],"strokeWidth":0}
          ],
          "texts": [
            {"id":"00000000-0000-0000-0000-000000000202","text":"Static","fontName":".AppleSystemUIFont","fontSize":24,"frame":{"x":0.1,"y":0.7,"width":0.6,"height":0.1},"colorRGBA":[1,1,1,1]}
          ]
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(OverlayCardDocument.self, from: json)
        XCTAssertNil(decoded.shapes.first?.timeoutSeconds)
        XCTAssertNil(decoded.texts.first?.metadataKey)
        XCTAssertNil(decoded.texts.first?.timeoutSeconds)
    }

    func testRemoteControlSettings_decodeLegacyDMXNetworkDefaults() throws {
        let json = """
        {
          "dmxOutputEnabled": true,
          "dmxOutputMode": "hardware",
          "dmxSimulatedInterface": "enttec_open_dmx"
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(RemoteControlSettings.self, from: json)
        XCTAssertEqual(decoded.dmxArtNetHost, "255.255.255.255")
        XCTAssertEqual(decoded.dmxNetworkUniverse, 0)
        XCTAssertEqual(decoded.dmxSACNHost, "239.255.0.1")
    }

    func testRemoteControlSettings_decodeLegacyFeedbackRelayDefaults() throws {
        let json = """
        {
          "githubFeedbackRepository": "a/b"
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(RemoteControlSettings.self, from: json)
        XCTAssertEqual(decoded.githubFeedbackRelayURL, "")
        XCTAssertEqual(decoded.githubFeedbackRelayToken, "")
    }

    func testRemoteControlSettings_decodeLegacyInboundDMXDefaults() throws {
        let json = """
        {
          "dmxOutputEnabled": true,
          "dmxOutputMode": "artnet"
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(RemoteControlSettings.self, from: json)
        XCTAssertFalse(decoded.dmxInboundEnabled)
        XCTAssertEqual(decoded.dmxInboundMode, "artnet")
        XCTAssertEqual(decoded.dmxInboundUniverse, 0)
        XCTAssertEqual(decoded.dmxInboundUniverseCount, 1)
        XCTAssertEqual(decoded.dmxInboundMergeMode, "htp")
    }

    func testRemoteControlSettings_decodeLegacyRDMDefaults() throws {
        let json = """
        {
          "dmxOutputEnabled": true,
          "dmxOutputMode": "hardware"
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(RemoteControlSettings.self, from: json)
        XCTAssertFalse(decoded.rdmDiscoveryEnabled)
        XCTAssertEqual(decoded.rdmDiscoveryTransportMode, "hardware")
        XCTAssertEqual(decoded.rdmDiscoveryUniverse, 0)
    }

    func testRemoteControlSettings_decodeLegacyOSCDefaults() throws {
        let json = """
        {
          "remoteControlEnabled": true,
          "remoteControlPort": 8765
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(RemoteControlSettings.self, from: json)
        XCTAssertFalse(decoded.oscControlEnabled)
        XCTAssertEqual(decoded.oscControlPort, 9000)
        XCTAssertFalse(decoded.oscBindLAN)
        XCTAssertEqual(decoded.oscAuthToken, "")
    }
}
