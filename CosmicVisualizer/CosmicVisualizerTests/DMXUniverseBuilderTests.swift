import XCTest
@testable import CosmicVisualizer

final class DMXUniverseBuilderTests: XCTestCase {
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
}
