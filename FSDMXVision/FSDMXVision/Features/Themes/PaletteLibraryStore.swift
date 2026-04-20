import Foundation

enum PaletteLibraryStore {
    private static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent(AppIdentity.applicationSupportFolderName, isDirectory: true)
            .appendingPathComponent("palettes.json")
    }

    struct Document: Codable, Equatable {
        var version: Int = 1
        var palettes: [ThemePalette]
    }

    static func loadOrDefault() -> [ThemePalette] {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let doc = try? JSONDecoder().decode(Document.self, from: data),
              !doc.palettes.isEmpty
        else {
            return ThemeBootstrap.drewSpacemanStarters
        }
        return doc.palettes
    }

    static func save(_ palettes: [ThemePalette]) throws {
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let doc = Document(palettes: palettes)
        let data = try JSONEncoder().encode(doc)
        try data.write(to: fileURL, options: .atomic)
    }
}
