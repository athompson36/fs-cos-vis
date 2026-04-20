import Foundation

/// Persists per-scene edit parameters (JSON map keyed by scene id).
final class SceneControlStore {
    struct Document: Codable, Equatable {
        var version: Int = 1
        var states: [UUID: SceneEditState]
    }

    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    }

    convenience init(applicationFilename: String = "scene_controls.json") {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent(AppIdentity.applicationSupportFolderName, isDirectory: true)
        self.init(fileURL: base.appendingPathComponent(applicationFilename))
    }

    func load() throws -> Document? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(Document.self, from: data)
    }

    func save(states: [UUID: SceneEditState]) throws {
        let doc = Document(states: states)
        let data = try JSONEncoder().encode(doc)
        try data.write(to: fileURL, options: .atomic)
    }
}
