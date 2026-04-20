import XCTest
@testable import FSDMXVision

final class ThemePackTests: XCTestCase {
    func testRoundTrip() throws {
        let pal = ThemePalette(name: "P", primaryHex: "#111111", secondaryHex: "#222222", accentHex: "#333333", glowHex: "#444444")
        let pack = ThemePack(name: "Pack", palettes: [pal])
        let data = try JSONEncoder().encode(pack)
        let decoded = try JSONDecoder().decode(ThemePack.self, from: data)
        XCTAssertEqual(decoded, pack)
    }

    func testBuiltIn_nonEmpty() {
        XCTAssertFalse(ThemePackLibrary.builtIn.isEmpty)
    }
}
