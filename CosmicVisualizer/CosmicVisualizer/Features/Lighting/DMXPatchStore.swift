import Foundation

enum DMXPatchStore {
    private static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CosmicVisualizer", isDirectory: true)
            .appendingPathComponent("dmx_patch.json")
    }

    static func loadOrDefault() -> DMXPatchDocument {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let doc = try? JSONDecoder().decode(DMXPatchDocument.self, from: data)
        else {
            return DMXPatchDocument.default()
        }
        return doc
    }

    static func save(_ doc: DMXPatchDocument) throws {
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(doc)
        try data.write(to: fileURL, options: .atomic)
    }
}
