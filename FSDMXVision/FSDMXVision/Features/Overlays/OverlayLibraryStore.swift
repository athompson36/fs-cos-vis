import AppKit
import Foundation
import UniformTypeIdentifiers

/// Persists overlay metadata and offers a simple import path via `NSOpenPanel`.
final class OverlayLibraryStore {
    struct Document: Codable, Equatable {
        var version: Int = 1
        var overlays: [OverlayAsset]
    }

    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    }

    convenience init(applicationFilename: String = "overlays.json") {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent(AppIdentity.applicationSupportFolderName, isDirectory: true)
        self.init(fileURL: base.appendingPathComponent(applicationFilename))
    }

    func load() throws -> Document? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(Document.self, from: data)
    }

    func save(overlays: [OverlayAsset]) throws {
        let doc = Document(overlays: overlays)
        let data = try JSONEncoder().encode(doc)
        try data.write(to: fileURL, options: .atomic)
    }

    /// Presents open panel; returns a new `OverlayAsset` if user confirms.
    func importOverlayViaOpenPanel() -> OverlayAsset? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        let name = url.deletingPathExtension().lastPathComponent
        return OverlayAsset(name: name, filePath: url.path, opacity: 1, blendMode: OverlayBlendMode.screen.rawValue)
    }
}
