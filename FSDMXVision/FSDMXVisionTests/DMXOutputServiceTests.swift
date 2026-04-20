import XCTest
@testable import FSDMXVision

@MainActor
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

    func testSACNPacket_builderEmitsFullE131Frame() {
        let frame = [UInt8](repeating: 3, count: 512)
        let packet = DMXNetworkPacketBuilder.makeSACNPacket(universe: 200, frame: frame, sequence: 42)
        XCTAssertEqual(packet.count, 638)
        XCTAssertEqual(packet[18], 0x00)
        XCTAssertEqual(packet[19], 0x00)
        XCTAssertEqual(packet[20], 0x00)
        XCTAssertEqual(packet[21], 0x04)
        XCTAssertEqual(packet[40], 0x00)
        XCTAssertEqual(packet[41], 0x00)
        XCTAssertEqual(packet[42], 0x00)
        XCTAssertEqual(packet[43], 0x02)
        XCTAssertEqual(packet[111], 42)
        XCTAssertEqual(packet[113], 0x00)
        XCTAssertEqual(packet[114], 0xC8)
        XCTAssertEqual(packet[125], 0x00)
        XCTAssertEqual(packet[126], 3)
    }

    func testInboundDMXPacketDecoder_artnetPacketRoundTrip() {
        let frame = [UInt8](repeating: 11, count: 512)
        let packet = DMXNetworkPacketBuilder.makeArtNetPacket(universe: 2, frame: frame)
        let decoded = DMXInboundPacketDecoder.decode(packet: packet, mode: "artnet")
        XCTAssertEqual(decoded?.universe, 2)
        XCTAssertEqual(decoded?.frame.count, 512)
        XCTAssertEqual(decoded?.frame.first, 11)
        XCTAssertEqual(decoded?.priority, DMXInboundDecoded.defaultPriority)
    }

    func testInboundDMXPacketDecoder_sacnPacketRoundTrip() {
        let frame = [UInt8](repeating: 19, count: 512)
        let packet = DMXNetworkPacketBuilder.makeSACNPacket(universe: 4, frame: frame, sequence: 0)
        let decoded = DMXInboundPacketDecoder.decode(packet: packet, mode: "sacn")
        XCTAssertEqual(decoded?.universe, 4)
        XCTAssertEqual(decoded?.frame.count, 512)
        XCTAssertEqual(decoded?.frame.first, 19)
        XCTAssertEqual(decoded?.priority, 100)
    }

    func testInboundDMXPacketDecoder_sacnPriorityFieldDecoded() {
        let frame = [UInt8](repeating: 5, count: 512)
        var packet = DMXNetworkPacketBuilder.makeSACNPacket(universe: 10, frame: frame, sequence: 1)
        XCTAssertEqual(packet[108], 100)
        packet[108] = 37
        let decoded = DMXInboundPacketDecoder.decode(packet: packet, mode: "sacn")
        XCTAssertEqual(decoded?.universe, 10)
        XCTAssertEqual(decoded?.priority, 37)
    }

    func testSACNMulticastAddress_matchesE131MulticastMapping() {
        XCTAssertEqual(SACNMulticastAddress.multicastString(forWireUniverse: 4), "239.255.0.4")
        XCTAssertEqual(SACNMulticastAddress.multicastString(forWireUniverse: 200), "239.255.0.200")
        XCTAssertEqual(SACNMulticastAddress.multicastString(forWireUniverse: 257), "239.255.1.1")
        XCTAssertEqual(SACNMulticastAddress.multicastString(forWireUniverse: 63999), "239.255.249.255")
    }

    func testSACNE131InboundClassifier_recognizesExtendedSyncAndDiscovery() {
        let frame = [UInt8](repeating: 0, count: 512)
        var data = DMXNetworkPacketBuilder.makeSACNPacket(universe: 1, frame: frame, sequence: 0)
        XCTAssertNil(SACNE131InboundClassifier.extendedNonDataKind(packet: data))
        data[18] = 0x00
        data[19] = 0x00
        data[20] = 0x00
        data[21] = 0x08
        data[40] = 0x00
        data[41] = 0x00
        data[42] = 0x00
        data[43] = 0x01
        XCTAssertEqual(SACNE131InboundClassifier.extendedNonDataKind(packet: data), .synchronization)
        data[43] = 0x02
        XCTAssertEqual(SACNE131InboundClassifier.extendedNonDataKind(packet: data), .universeDiscovery)
        data[43] = 0x03
        XCTAssertNil(SACNE131InboundClassifier.extendedNonDataKind(packet: data))
    }

    func testInboundDMXPacketDecoder_sacnLegacyScaffoldStillDecodes() {
        var legacy = Array("ASC-E1.31".utf8)
        legacy += [0x00, 0x04]
        legacy += [UInt8](repeating: 7, count: 512)
        let decoded = DMXInboundPacketDecoder.decode(packet: legacy, mode: "sacn")
        XCTAssertEqual(decoded?.universe, 4)
        XCTAssertEqual(decoded?.frame.first, 7)
        XCTAssertEqual(decoded?.priority, DMXInboundDecoded.defaultPriority)
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
        profiler.recordFrame(
            buildMS: 4.0, sendMS: 2.0, totalMS: 10.0, budgetMS: 22.7,
            rigFixtureInstanceCount: 12, rigModulatorCount: 3, outputLogicalUniverseCount: 2
        )
        profiler.recordFrame(
            buildMS: 8.0, sendMS: 3.0, totalMS: 28.0, budgetMS: 22.7,
            rigFixtureInstanceCount: 40, rigModulatorCount: 5, outputLogicalUniverseCount: 4
        )
        let snapshot = profiler.snapshot()
        XCTAssertEqual(snapshot.frameCount, 2)
        XCTAssertEqual(snapshot.overBudgetFrameCount, 1)
        XCTAssertEqual(snapshot.avgBuildMS, 6.0, accuracy: 0.001)
        XCTAssertEqual(snapshot.avgSendMS, 2.5, accuracy: 0.001)
        XCTAssertEqual(snapshot.avgTotalMS, 19.0, accuracy: 0.001)
        XCTAssertEqual(snapshot.maxBuildMS, 8.0, accuracy: 0.001)
        XCTAssertEqual(snapshot.maxSendMS, 3.0, accuracy: 0.001)
        XCTAssertEqual(snapshot.maxTotalMS, 28.0, accuracy: 0.001)
        XCTAssertEqual(snapshot.totalMSHistogramBinCounts, [0, 0, 0, 0, 1, 0, 0, 1, 0])
        XCTAssertNotNil(snapshot.approxMedianTotalMS)
        XCTAssertNotNil(snapshot.approxP95TotalMS)
        XCTAssertEqual(snapshot.approxMedianTotalMS!, 12.0, accuracy: 0.001)
        XCTAssertEqual(snapshot.approxP95TotalMS!, 38.4, accuracy: 0.001)
        XCTAssertNotNil(snapshot.approxMedianBuildMS)
        XCTAssertNotNil(snapshot.approxP95BuildMS)
        XCTAssertEqual(snapshot.approxMedianBuildMS!, 6.0, accuracy: 0.001)
        XCTAssertEqual(snapshot.approxP95BuildMS!, 11.6, accuracy: 0.001)
        XCTAssertNotNil(snapshot.approxMedianSendMS)
        XCTAssertNotNil(snapshot.approxP95SendMS)
        XCTAssertEqual(snapshot.approxMedianSendMS!, 3.0, accuracy: 0.001)
        XCTAssertEqual(snapshot.approxP95SendMS!, 3.9, accuracy: 0.001)
        XCTAssertEqual(snapshot.rigFixtureInstanceCount, 40)
        XCTAssertEqual(snapshot.rigModulatorCount, 5)
        XCTAssertEqual(snapshot.outputLogicalUniverseCount, 4)
    }

    func testDMXPerformanceProfiler_histogramQuantile_uniformBin() {
        var profiler = DMXPerformanceProfiler()
        for _ in 0 ..< 100 {
            profiler.recordFrame(
                buildMS: 1.0, sendMS: 1.0, totalMS: 5.0, budgetMS: 22.7,
                rigFixtureInstanceCount: 1, rigModulatorCount: 0, outputLogicalUniverseCount: 1
            )
        }
        let snapshot = profiler.snapshot()
        XCTAssertNotNil(snapshot.approxMedianTotalMS)
        XCTAssertNotNil(snapshot.approxP95TotalMS)
        XCTAssertEqual(snapshot.approxMedianTotalMS!, 5.0, accuracy: 0.02)
        // p95 rank 95 in [4,6): 4 + 0.95 * 2 = 5.9
        XCTAssertEqual(snapshot.approxP95TotalMS!, 5.9, accuracy: 0.02)
    }

    func testDMXPerformanceProfiler_approximateDurationQuantile_direct() {
        let bins: [UInt64] = [0, 0, 100, 0, 0, 0, 0, 0, 0]
        let q = DMXPerformanceProfiler.approximateDurationQuantile(
            bins: bins, frameCount: 100, quantile: 0.5, maxObservedMS: 5.5
        )
        XCTAssertNotNil(q)
        XCTAssertEqual(q!, 5.0, accuracy: 0.001)
    }

    func testDMXPerformanceProfiler_resetClearsAccumulators() {
        var profiler = DMXPerformanceProfiler()
        profiler.recordFrame(
            buildMS: 4.0, sendMS: 2.0, totalMS: 10.0, budgetMS: 22.7,
            rigFixtureInstanceCount: 3, rigModulatorCount: 1, outputLogicalUniverseCount: 2
        )
        XCTAssertEqual(profiler.snapshot().frameCount, 1)
        profiler.reset()
        let cleared = profiler.snapshot()
        XCTAssertEqual(cleared.frameCount, 0)
        XCTAssertEqual(cleared.overBudgetFrameCount, 0)
        XCTAssertEqual(cleared.maxTotalMS, 0, accuracy: 0.001)
        XCTAssertEqual(cleared.totalMSHistogramBinCounts, [UInt64](repeating: 0, count: DMXPerformanceProfiler.totalMSHistogramBinCount))
        XCTAssertNil(cleared.approxMedianBuildMS)
        XCTAssertNil(cleared.approxMedianSendMS)
        XCTAssertNil(cleared.exactMedianTotalMS)
        XCTAssertNil(cleared.exactP95TotalMS)
    }

    func testDMXPerformanceProfiler_exactQuantilesFromRing() {
        var profiler = DMXPerformanceProfiler()
        for _ in 0 ..< 100 {
            profiler.recordFrame(
                buildMS: 1.0, sendMS: 1.0, totalMS: 5.0, budgetMS: 22.7,
                rigFixtureInstanceCount: 1, rigModulatorCount: 0, outputLogicalUniverseCount: 1
            )
        }
        let s = profiler.snapshot()
        XCTAssertNotNil(s.exactMedianTotalMS)
        XCTAssertNotNil(s.exactP95TotalMS)
        XCTAssertEqual(s.exactMedianTotalMS!, 5.0, accuracy: 0.000_1)
        XCTAssertEqual(s.exactP95TotalMS!, 5.0, accuracy: 0.000_1)
    }

    func testDMXPerformanceProfiler_exactQuantile_interpolatedMedian() {
        var profiler = DMXPerformanceProfiler()
        profiler.recordFrame(
            buildMS: 1.0, sendMS: 1.0, totalMS: 0.0, budgetMS: 22.7,
            rigFixtureInstanceCount: 1, rigModulatorCount: 0, outputLogicalUniverseCount: 1
        )
        profiler.recordFrame(
            buildMS: 1.0, sendMS: 1.0, totalMS: 10.0, budgetMS: 22.7,
            rigFixtureInstanceCount: 1, rigModulatorCount: 0, outputLogicalUniverseCount: 1
        )
        let s = profiler.snapshot()
        XCTAssertEqual(s.exactMedianTotalMS!, 5.0, accuracy: 0.000_1)
    }

    func testArtNetArtPollDiscovery_pollPacketLayout() {
        let p = ArtNetArtPollDiscovery.makeArtPollPacket()
        XCTAssertEqual(p.count, 14)
        XCTAssertEqual(String(decoding: p.prefix(8), as: UTF8.self), "Art-Net\u{0}")
        XCTAssertEqual(p[8], 0x00)
        XCTAssertEqual(p[9], 0x20)
    }

    func testArtNetArtPollDiscovery_parsesMinimalPollReply() {
        var d = [UInt8](repeating: 0, count: 42)
        let art = Array("Art-Net\u{0}".utf8)
        for k in 0 ..< 8 { d[k] = art[k] }
        d[8] = 0x00
        d[9] = 0x21
        let label = Array("Node-A".utf8)
        for i in 0 ..< min(18, label.count) {
            d[21 + i] = label[i]
        }
        let dev = ArtNetArtPollDiscovery.parseArtPollReply(d, sourceIPv4: "192.168.1.40")
        XCTAssertEqual(dev?.modelLabel, "Node-A")
        XCTAssertEqual(dev?.manufacturer, "Art-Net")
        XCTAssertEqual(dev?.uid, "ip:192.168.1.40")
    }

    func testSACNE131InboundClassifier_syncUniverseField() {
        let syncHex = "001000004153432d45312e313700000070210000000800000000000000000000000000000000700b000000010730390000"
        let packet = Self.bytes(fromHex: syncHex)
        XCTAssertEqual(packet.count, 49)
        XCTAssertEqual(SACNE131InboundClassifier.synchronizationSyncWireUniverse(packet: packet), 12_345)
    }

    func testSACNE131InboundClassifier_universeDiscoveryList() {
        let udlHex = "001000004153432d45312e3137000000706e00000008ef07c8dd00644401a3a2459ef8e6143e705800000002536f757263655f41000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000700e000000010001000100020003"
        let packet = Self.bytes(fromHex: udlHex)
        XCTAssertEqual(packet.count, 126)
        let list = SACNE131InboundClassifier.universeDiscoveryWireUniverses(packet: packet)
        XCTAssertEqual(list, [1, 2, 3])
    }

    func testDMXInboundMergeLogic_priorityRejectsLowerWhenFresh() {
        let t0 = CFAbsoluteTime(1_000_000)
        XCTAssertFalse(
            DMXInboundMergeLogic.shouldStoreNewInboundFrame(
                existingReceivedAt: t0,
                existingPriority: 100,
                newPriority: 50,
                now: t0 + 1
            )
        )
        XCTAssertTrue(
            DMXInboundMergeLogic.shouldStoreNewInboundFrame(
                existingReceivedAt: t0,
                existingPriority: 50,
                newPriority: 100,
                now: t0 + 1
            )
        )
    }

    func testDMXInboundMergeLogic_equalOrHigherPriorityReplacesWhenFresh() {
        let t0 = CFAbsoluteTime(2_000_000)
        XCTAssertTrue(
            DMXInboundMergeLogic.shouldStoreNewInboundFrame(
                existingReceivedAt: t0,
                existingPriority: 80,
                newPriority: 80,
                now: t0 + 0.5
            )
        )
        XCTAssertTrue(
            DMXInboundMergeLogic.shouldStoreNewInboundFrame(
                existingReceivedAt: t0,
                existingPriority: 80,
                newPriority: 81,
                now: t0 + 0.5
            )
        )
    }

    func testDMXInboundMergeLogic_staleWindowAllowsLowerPriority() {
        let t0 = CFAbsoluteTime(3_000_000)
        XCTAssertTrue(
            DMXInboundMergeLogic.shouldStoreNewInboundFrame(
                existingReceivedAt: t0,
                existingPriority: 100,
                newPriority: 10,
                now: t0 + 4
            )
        )
    }

    func testDMXInboundMergeLogic_htpPerChannelMax() {
        var sw = [UInt8](repeating: 0, count: 512)
        sw[0] = 10
        sw[1] = 200
        let inbound = [UInt8](repeating: 0, count: 512)
        var inc = inbound
        inc[0] = 50
        inc[1] = 100
        DMXInboundMergeLogic.applyHTPMerge(software: &sw, inbound: inc)
        XCTAssertEqual(sw[0], 50)
        XCTAssertEqual(sw[1], 200)
    }

    func testDMXInboundMergeLogic_ltpReplacesBuffer() {
        var sw = [UInt8](repeating: 7, count: 512)
        let inbound = [UInt8](repeating: 9, count: 512)
        DMXInboundMergeLogic.applyLTPMergeReplaceUniverse(software: &sw, inbound: inbound)
        XCTAssertEqual(sw[0], 9)
    }

    func testDMXInboundMergeLogic_freshWindowMatchesDefault() {
        let t0 = CFAbsoluteTime(4_000_000)
        XCTAssertTrue(DMXInboundMergeLogic.isFrameFresh(receivedAt: t0, now: t0 + 2.9))
        XCTAssertFalse(DMXInboundMergeLogic.isFrameFresh(receivedAt: t0, now: t0 + 3.1))
    }

    private static func bytes(fromHex hex: String) -> [UInt8] {
        var out: [UInt8] = []
        var i = hex.startIndex
        while i < hex.endIndex {
            let j = hex.index(i, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
            let pair = hex[i ..< j]
            XCTAssertEqual(pair.count, 2)
            out.append(UInt8(String(pair), radix: 16)!)
            i = j
        }
        return out
    }
}
