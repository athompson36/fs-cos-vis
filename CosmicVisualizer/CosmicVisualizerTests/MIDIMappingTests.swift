import XCTest
@testable import CosmicVisualizer

final class MIDIMappingTests: XCTestCase {
    func testDecode_legacyJSON_withoutContinuousCC_defaultsEmptyThenStoreMerges() throws {
        let legacy = """
        {"cc":[{"channel":0,"controller":20,"commandType":"NextScene"}]}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(MIDIMapping.self, from: legacy)
        XCTAssertTrue(decoded.continuousCC.isEmpty)
        XCTAssertEqual(decoded.cc.count, 1)
    }

    func testEncodeRoundTrip_includesContinuous() throws {
        var m = MIDIMapping.default()
        m.learnContinuous(parameter: .compositeBlend, channel: 2, controller: 7)
        let data = try JSONEncoder().encode(m)
        let back = try JSONDecoder().decode(MIDIMapping.self, from: data)
        XCTAssertEqual(back.continuousCC.count, m.continuousCC.count)
        XCTAssertEqual(back.layerParameter(forChannel: 2, controller: 7), .compositeBlend)
    }
}
