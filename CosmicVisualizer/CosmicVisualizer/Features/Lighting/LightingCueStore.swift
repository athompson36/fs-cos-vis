import Foundation

enum LightingCueStore {
    private static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CosmicVisualizer", isDirectory: true)
            .appendingPathComponent("lighting_cues.json")
    }

    static func loadOrDefault() -> LightingCueDocument {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let doc = try? JSONDecoder().decode(LightingCueDocument.self, from: data)
        else {
            return LightingCueDocument.default()
        }
        return doc
    }

    static func save(_ doc: LightingCueDocument) throws {
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(doc)
        try data.write(to: fileURL, options: .atomic)
    }
}
