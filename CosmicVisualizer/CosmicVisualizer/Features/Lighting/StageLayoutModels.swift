import Foundation

enum StageLayoutBackdropSupport {
    private static var stageDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CosmicVisualizer", isDirectory: true)
            .appendingPathComponent("Stage", isDirectory: true)
    }

    static func copyBackdropToAppSupport(from sourceURL: URL, id: UUID) throws -> String {
        try FileManager.default.createDirectory(at: stageDirectory, withIntermediateDirectories: true)
        let ext = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
        let dest = stageDirectory.appendingPathComponent("\(id.uuidString).\(ext.lowercased())")
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: sourceURL, to: dest)
        return dest.path
    }
}

struct StagePlacement: Codable, Equatable, Sendable {
    var x: Double
    var y: Double
    var rotation: Double

    init(x: Double = 0.5, y: Double = 0.5, rotation: Double = 0) {
        self.x = x
        self.y = y
        self.rotation = rotation
    }
}

struct StageLayoutDocument: Codable, Equatable, Sendable {
    var version: Int
    /// Optional imported PNG/SVG path in app support (future).
    var backdropAssetPath: String?
    /// Fixture instance UUID string -> normalized 0...1 stage position.
    var placements: [String: StagePlacement]

    static let currentVersion = 1

    init(version: Int = currentVersion, backdropAssetPath: String? = nil, placements: [String: StagePlacement] = [:]) {
        self.version = version
        self.backdropAssetPath = backdropAssetPath
        self.placements = placements
    }
}

enum StageLayoutStore {
    private static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CosmicVisualizer", isDirectory: true)
            .appendingPathComponent("stage_layout.json")
    }

    static func loadOrDefault() -> StageLayoutDocument {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let doc = try? JSONDecoder().decode(StageLayoutDocument.self, from: data)
        else {
            return StageLayoutDocument()
        }
        return doc
    }

    static func save(_ doc: StageLayoutDocument) throws {
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(doc)
        try data.write(to: fileURL, options: .atomic)
    }
}
