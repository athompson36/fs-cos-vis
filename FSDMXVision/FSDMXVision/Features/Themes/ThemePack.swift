import Foundation

/// Bundles several palettes for quick swapping (install / preset packs).
struct ThemePack: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var palettes: [ThemePalette]

    init(id: UUID = UUID(), name: String, palettes: [ThemePalette]) {
        self.id = id
        self.name = name
        self.palettes = palettes
    }
}

enum ThemePackLibrary {
    static let builtIn: [ThemePack] = [
        ThemePack(name: "Drew Spaceman Core", palettes: ThemeBootstrap.drewSpacemanStarters),
    ]
}
