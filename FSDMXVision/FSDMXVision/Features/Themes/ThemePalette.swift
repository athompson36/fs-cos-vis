import Foundation

struct ThemePalette: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var primaryHex: String
    var secondaryHex: String
    var accentHex: String
    var glowHex: String

    init(
        id: UUID = UUID(),
        name: String,
        primaryHex: String,
        secondaryHex: String,
        accentHex: String,
        glowHex: String
    ) {
        self.id = id
        self.name = name
        self.primaryHex = primaryHex
        self.secondaryHex = secondaryHex
        self.accentHex = accentHex
        self.glowHex = glowHex
    }
}
