import Foundation

/// Persists the ordered scene list (JSON).
final class SceneLibraryStore {
    struct Document: Codable, Equatable {
        var version: Int = 1
        var scenes: [VisualizationScene]
    }

    private let fileURL: URL

    /// Designated initializer — use for tests with a temporary file URL.
    init(fileURL: URL) {
        self.fileURL = fileURL
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    }

    convenience init(applicationFilename: String = "scenes.json") {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CosmicVisualizer", isDirectory: true)
        self.init(fileURL: base.appendingPathComponent(applicationFilename))
    }

    func load() throws -> Document? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(Document.self, from: data)
    }

    func save(scenes: [VisualizationScene]) throws {
        let doc = Document(scenes: scenes)
        let data = try JSONEncoder().encode(doc)
        try data.write(to: fileURL, options: .atomic)
    }
}
