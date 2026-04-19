import XCTest
@testable import CosmicVisualizer

@MainActor
final class DMXUniverseBuilderTests: XCTestCase {
    func testDefaultPatch_includesExtendedFixtureProfiles() {
        let p = DMXPatchDocument.default()
        XCTAssertGreaterThanOrEqual(p.profiles.count, 4)
        XCTAssertTrue(p.profiles.contains { $0.name.contains("Fog") || $0.name.contains("haze") })
        XCTAssertTrue(p.profiles.contains { $0.name.contains("RGBW") })
    }

    func testLegacySlotsFillFirstFiveChannels() {
        let model = AppModel()
        model.sceneManager.currentIndex = 2
        var smooth: [UUID: Float] = [:]
        let u = model.buildDMXUniverse(time: 0, lastSmoothed: &smooth)
        XCTAssertEqual(u.count, 512)
        XCTAssertEqual(u[0], 2)
    }

    func testCueMapOverridesChannel() {
        let model = AppModel()
        var doc = LightingCueDocument.default()
        doc.cues = [
            LightingCue(name: "Full", channelValues: [ChannelValue(channel: 10, value: 128)]),
        ]
        doc.activeCueIndex = 0
        model.applyLightingCueDocument(doc)
        var smooth: [UUID: Float] = [:]
        let u = model.buildDMXUniverse(time: 0, lastSmoothed: &smooth)
        XCTAssertEqual(u[9], 128)
    }

    func testHazeEmergencyKill_forcesHazeOutputAndPumpToZero() {
        let model = AppModel()
        var patch = DMXPatchDocument.default()
        guard let fogProfile = patch.profiles.first(where: { $0.channels.contains { $0.role == .hazeOutput } }) else {
            XCTFail("Expected fog profile in default patch")
            return
        }
        let inst = FixtureInstance(profileID: fogProfile.id, universe: 0, startAddress: 10, manualValues: [
            "0": 200, "1": 90, "2": 180,
        ])
        patch.instances = [inst]
        model.applyDMXPatchDocument(patch)
        var doc = LightingCueDocument.default()
        doc.cues = [
            LightingCue(
                name: "Foggy",
                channelValues: [
                    ChannelValue(channel: 10, value: 250),
                    ChannelValue(channel: 11, value: 88),
                    ChannelValue(channel: 12, value: 222),
                ]
            ),
        ]
        doc.activeCueIndex = 0
        model.applyLightingCueDocument(doc)
        model.setHazeEmergencyKill(true)
        var smooth: [UUID: Float] = [:]
        let u = model.buildDMXUniverse(time: CFAbsoluteTimeGetCurrent(), lastSmoothed: &smooth)
        XCTAssertEqual(u[9], 0, "hazeOutput DMX 10")
        XCTAssertEqual(u[11], 0, "hazePump DMX 12")
        XCTAssertEqual(u[10], 88, "hazeFan DMX 11 unchanged from cue")
        model.setHazeEmergencyKill(false)
    }

    func testResolvedCueChannelMap_matchesActiveCue() {
        let model = AppModel()
        var doc = LightingCueDocument.default()
        doc.cues = [
            LightingCue(name: "Hit", channelValues: [ChannelValue(channel: 44, value: 201)]),
        ]
        doc.activeCueIndex = 0
        model.applyLightingCueDocument(doc)
        let m = model.resolvedCueChannelMap(at: CFAbsoluteTimeGetCurrent())
        XCTAssertEqual(m[44], 201)
    }

    func testPatchAudit_detectsOverlappingAddresses() {
        var patch = DMXPatchDocument.default()
        let rgb = patch.profiles.first(where: { $0.name.contains("RGB") })!
        patch.instances = [
            FixtureInstance(profileID: rgb.id, startAddress: 10, manualValues: [:]),
            FixtureInstance(profileID: rgb.id, startAddress: 12, manualValues: [:]),
        ]
        let msgs = DMXPatchAudit.universeZeroConflictMessages(patch: patch)
        XCTAssertFalse(msgs.isEmpty, "Expected overlap on channels 12–13 for two 4-channel fixtures at 10 and 12")
        XCTAssertTrue(msgs.contains { $0.contains("Channel 12") })
    }

    func testDMXPatchDocument_JSONRoundTrip() throws {
        let original = DMXPatchDocument.default()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DMXPatchDocument.self, from: data)
        XCTAssertEqual(decoded.profiles.count, original.profiles.count)
        XCTAssertEqual(decoded.instances.count, original.instances.count)
        XCTAssertEqual(decoded.useLegacyVisualizationSlots, original.useLegacyVisualizationSlots)
    }

    func testSuggestNextAddresses_excludingInstanceFreesThatSpan() {
        let svc = LightingCopilotService()
        var patch = DMXPatchDocument.default()
        let rgb = patch.profiles.first(where: { $0.name.contains("RGB") })!
        let id1 = UUID()
        let id2 = UUID()
        patch.instances = [
            FixtureInstance(id: id1, profileID: rgb.id, startAddress: 1, manualValues: [:]),
            FixtureInstance(id: id2, profileID: rgb.id, startAddress: 10, manualValues: [:]),
        ]
        let packed = svc.suggestNextAddresses(patch: patch, profile: rgb, count: 1, excludingInstanceIDs: [])
        XCTAssertEqual(packed.first, 5)
        let freeingFirst = svc.suggestNextAddresses(patch: patch, profile: rgb, count: 1, excludingInstanceIDs: Set([id1]))
        XCTAssertEqual(freeingFirst.first, 1)
    }

    func testStageLayoutDocument_JSONRoundTrip() throws {
        let original = StageLayoutDocument()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StageLayoutDocument.self, from: data)
        XCTAssertEqual(decoded.version, original.version)
    }

    func testFixtureAndProfileIndex_findsChannelSlot() {
        var patch = DMXPatchDocument.default()
        let rgb = patch.profiles.first(where: { $0.name.contains("RGB") })!
        patch.instances = [
            FixtureInstance(profileID: rgb.id, startAddress: 20, manualValues: [:]),
        ]
        let hit = DMXPatchAudit.fixtureAndProfileIndex(forDMXChannel: 22, patch: patch)
        XCTAssertEqual(hit?.channelIndex, 2)
        XCTAssertEqual(hit?.instance.startAddress, 20)
    }

    func testLightingWorkspaceBundle_JSONRoundTrip() throws {
        let bundle = LightingWorkspaceBundle(
            dmxPatch: DMXPatchDocument.default(),
            lightingCues: LightingCueDocument.default(),
            modulation: ModulationDocument.default(),
            stageLayout: StageLayoutDocument()
        )
        let data = try JSONEncoder().encode(bundle)
        let decoded = try JSONDecoder().decode(LightingWorkspaceBundle.self, from: data)
        XCTAssertEqual(decoded.version, bundle.version)
        XCTAssertEqual(decoded.dmxPatch.profiles.count, bundle.dmxPatch.profiles.count)
    }

    func testBuildDMXUniversesForNetwork_splitsFixtureUniverses() {
        let model = AppModel()
        var patch = DMXPatchDocument.default()
        patch.useLegacyVisualizationSlots = false
        let rgb = patch.profiles.first(where: { $0.name.contains("RGB") })!
        patch.instances = [
            FixtureInstance(profileID: rgb.id, universe: 0, startAddress: 10, manualValues: ["0": 100]),
            FixtureInstance(profileID: rgb.id, universe: 1, startAddress: 10, manualValues: ["0": 88]),
        ]
        model.applyDMXPatchDocument(patch)
        var smooth: [UUID: Float] = [:]
        let per = model.buildDMXUniversesForNetwork(time: 0, lastSmoothed: &smooth)
        XCTAssertEqual(per[0]?[9], 100)
        XCTAssertEqual(per[1]?[9], 88)
    }
}
