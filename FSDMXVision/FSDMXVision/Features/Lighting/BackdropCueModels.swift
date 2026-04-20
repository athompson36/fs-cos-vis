import Foundation

/// One backdrop cue: snapshot of stage layout + optional backdrop asset path.
struct BackdropCue: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    /// Serialized copy of `StageLayoutDocument` at cue save time.
    var layoutSnapshot: StageLayoutDocument
    /// Optional path to backdrop image (absolute or project-relative).
    var backdropImagePath: String?

    init(
        id: UUID = UUID(),
        name: String,
        layoutSnapshot: StageLayoutDocument,
        backdropImagePath: String? = nil
    ) {
        self.id = id
        self.name = name
        self.layoutSnapshot = layoutSnapshot
        self.backdropImagePath = backdropImagePath
    }
}

struct BackdropCueDocument: Codable, Equatable, Sendable {
    static let currentVersion = 1

    var version: Int
    var cues: [BackdropCue]
    var activeCueIndex: Int?
    var bookmarkedCueIds: [UUID]

    init(
        version: Int = currentVersion,
        cues: [BackdropCue] = [],
        activeCueIndex: Int? = nil,
        bookmarkedCueIds: [UUID] = []
    ) {
        self.version = version
        self.cues = cues
        self.activeCueIndex = activeCueIndex
        self.bookmarkedCueIds = bookmarkedCueIds
    }

    static func `default`() -> BackdropCueDocument {
        BackdropCueDocument(cues: [], activeCueIndex: nil, bookmarkedCueIds: [])
    }
}

enum BackdropCueStore {
    private static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent(AppIdentity.applicationSupportFolderName, isDirectory: true)
            .appendingPathComponent("backdrop_cues.json")
    }

    static func loadOrDefault() -> BackdropCueDocument {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let doc = try? JSONDecoder().decode(BackdropCueDocument.self, from: data)
        else {
            return BackdropCueDocument.default()
        }
        return doc
    }

    static func save(_ doc: BackdropCueDocument) throws {
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(doc)
        try data.write(to: fileURL, options: .atomic)
    }
}
