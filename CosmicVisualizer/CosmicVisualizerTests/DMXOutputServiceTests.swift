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

    func testCuratedCatalog_includesFallbackSourceEntries() throws {
        let json = """
        {
          "manufacturers": {"adj":"ADJ"},
          "fixtures": {
            "adj/mega-par-profile": {"name":"Mega Par Profile","categories":["Color Changer"]}
          }
        }
        """.data(using: .utf8)!
        let cache = try OFLFixtureImportService.buildCuratedCatalog(from: json, limitPerManufacturer: 20)
        XCTAssertTrue(cache.entries.contains(where: { $0.source == .curatedLocal }))
        XCTAssertTrue(cache.entries.contains(where: { $0.fixtureSlug == "intimidator-spot-260x" }))
    }

    func testCuratedCatalog_decodesLegacyEntriesWithoutSource() throws {
        let json = """
        {
          "generatedAt": "2026-04-17T00:00:00Z",
          "entries": [
            {
              "manufacturerSlug": "adj",
              "manufacturerName": "ADJ",
              "fixtureSlug": "legacy-fixture",
              "fixtureName": "Legacy Fixture",
              "categories": ["Effect"],
              "isFogRelated": false
            }
          ]
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let cache = try decoder.decode(OFLFixtureImportService.CatalogCache.self, from: json)
        XCTAssertEqual(cache.entries.count, 1)
        XCTAssertEqual(cache.entries[0].source, .oflCurated)
    }

    func testDMXMode_serialPathRequirement() {
        XCTAssertTrue(DMXNetworkPacketBuilder.requiresSerialPath(mode: "hardware"))
        XCTAssertFalse(DMXNetworkPacketBuilder.requiresSerialPath(mode: "simulated"))
        XCTAssertFalse(DMXNetworkPacketBuilder.requiresSerialPath(mode: "artnet"))
        XCTAssertFalse(DMXNetworkPacketBuilder.requiresSerialPath(mode: "sacn"))
    }

    func testArtNetPacket_builderEncodesHeaderAndUniverse() {
        let frame = [UInt8](repeating: 7, count: 512)
        let packet = DMXNetworkPacketBuilder.makeArtNetPacket(universe: 15, frame: frame)
        XCTAssertEqual(String(decoding: packet.prefix(8), as: UTF8.self), "Art-Net\u{0}")
        XCTAssertEqual(packet[8], 0x00)
        XCTAssertEqual(packet[9], 0x50)
        XCTAssertEqual(packet[14], 15)
        XCTAssertEqual(packet[15], 0x00)
        XCTAssertEqual(packet[16], 0x02)
        XCTAssertEqual(packet[17], 0x00)
        XCTAssertEqual(packet.count, 18 + 512)
    }

    func testSACNPacket_builderIncludesUniversePrefix() {
        let frame = [UInt8](repeating: 3, count: 512)
        let packet = DMXNetworkPacketBuilder.makeSACNPacket(universe: 200, frame: frame)
        XCTAssertEqual(String(decoding: packet.prefix(9), as: UTF8.self), "ASC-E1.31")
        XCTAssertEqual(packet[9], 0x00)
        XCTAssertEqual(packet[10], 0xC8)
        XCTAssertEqual(packet.count, 11 + 512)
    }

    func testInboundDMXPacketDecoder_artnetPacketRoundTrip() {
        let frame = [UInt8](repeating: 11, count: 512)
        let packet = DMXNetworkPacketBuilder.makeArtNetPacket(universe: 2, frame: frame)
        let decoded = DMXInboundPacketDecoder.decode(packet: packet, mode: "artnet")
        XCTAssertEqual(decoded?.universe, 2)
        XCTAssertEqual(decoded?.frame.count, 512)
        XCTAssertEqual(decoded?.frame.first, 11)
    }

    func testInboundDMXPacketDecoder_sacnPacketRoundTrip() {
        let frame = [UInt8](repeating: 19, count: 512)
        let packet = DMXNetworkPacketBuilder.makeSACNPacket(universe: 4, frame: frame)
        let decoded = DMXInboundPacketDecoder.decode(packet: packet, mode: "sacn")
        XCTAssertEqual(decoded?.universe, 4)
        XCTAssertEqual(decoded?.frame.count, 512)
        XCTAssertEqual(decoded?.frame.first, 19)
    }

    func testRDMDiscoveryService_mockProbeReturnsDeterministicEntries() async {
        let service = RDMDiscoveryService()
        let result = await service.runMockProbe(
            mode: "hardware",
            universe: 0,
            serialPath: "/dev/cu.usbserial-test"
        )
        XCTAssertEqual(result.mode, "hardware")
        XCTAssertEqual(result.universe, 0)
        XCTAssertEqual(result.devices.count, 2)
        XCTAssertTrue(result.devices.allSatisfy { !$0.uid.isEmpty })
    }

    func testDMXPerformanceProfiler_tracksAveragesAndOverBudgetFrames() {
        var profiler = DMXPerformanceProfiler()
        profiler.recordFrame(buildMS: 4.0, sendMS: 2.0, totalMS: 10.0, budgetMS: 22.7)
        profiler.recordFrame(buildMS: 8.0, sendMS: 3.0, totalMS: 28.0, budgetMS: 22.7)
        let snapshot = profiler.snapshot()
        XCTAssertEqual(snapshot.frameCount, 2)
        XCTAssertEqual(snapshot.overBudgetFrameCount, 1)
        XCTAssertEqual(snapshot.avgBuildMS, 6.0, accuracy: 0.001)
        XCTAssertEqual(snapshot.avgSendMS, 2.5, accuracy: 0.001)
        XCTAssertEqual(snapshot.avgTotalMS, 19.0, accuracy: 0.001)
        XCTAssertEqual(snapshot.maxTotalMS, 28.0, accuracy: 0.001)
    }
}
