import Foundation

// MARK: - Venue / show metadata

struct VenueMetadata: Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    /// Optional room dimensions in meters (width, depth, height).
    var widthMeters: Double?
    var depthMeters: Double?
    var heightMeters: Double?
    var notes: String

    init(
        id: UUID = UUID(),
        name: String = "Untitled venue",
        widthMeters: Double? = nil,
        depthMeters: Double? = nil,
        heightMeters: Double? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.widthMeters = widthMeters
        self.depthMeters = depthMeters
        self.heightMeters = heightMeters
        self.notes = notes
    }
}

struct ShowMetadata: Codable, Equatable, Sendable {
    var id: UUID
    var title: String
    var subtitle: String

    init(id: UUID = UUID(), title: String = "Untitled show", subtitle: String = "") {
        self.id = id
        self.title = title
        self.subtitle = subtitle
    }
}

/// Root document for a saved venue/show workspace (JSON next to media folder).
struct ShowProjectDocument: Codable, Equatable, Sendable {
    static let currentVersion = 1

    var version: Int
    var venue: VenueMetadata
    var show: ShowMetadata
    /// Relative paths inside package (e.g. "Media/stage.png").
    var stagePlotAssetPath: String?
    var updatedAt: Date

    init(
        version: Int = currentVersion,
        venue: VenueMetadata = VenueMetadata(),
        show: ShowMetadata = ShowMetadata(),
        stagePlotAssetPath: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.version = version
        self.venue = venue
        self.show = show
        self.stagePlotAssetPath = stagePlotAssetPath
        self.updatedAt = updatedAt
    }
}

enum ShowProjectPackage {
    private static let projectFilename = "project.json"
    private static let scenesFilename = "scenes.json"
    private static let sceneControlsFilename = "scene_controls.json"
    private static let dmxPatchFilename = "dmx_patch.json"
    private static let lightingCuesFilename = "lighting_cues.json"
    private static let backdropCuesFilename = "backdrop_cues.json"
    private static let modulationFilename = "modulation.json"
    private static let stageLayoutFilename = "stage_layout.json"
    private static let overlayCardsFilename = "overlay_cards.json"
    private static let mediaDir = "Media"
    private static let archiveExtension = "cosmicshow.zip"

    static func defaultProjectsRoot() -> URL {
        AppIdentity.applicationSupportDirectory()
            .appendingPathComponent("Projects", isDirectory: true)
    }

    /// Writes a flat folder package: project.json + JSON payloads + Media/.
    static func save(
        to folder: URL,
        project: ShowProjectDocument,
        scenesData: Data,
        sceneControlsData: Data,
        dmxPatchData: Data,
        lightingCuesData: Data,
        backdropCuesData: Data,
        modulationData: Data,
        stageLayoutData: Data,
        overlayCardsData: Data
    ) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        var meta = project
        meta.updatedAt = Date()
        try enc.encode(meta).write(to: folder.appendingPathComponent(projectFilename), options: .atomic)
        try scenesData.write(to: folder.appendingPathComponent(scenesFilename), options: .atomic)
        try sceneControlsData.write(to: folder.appendingPathComponent(sceneControlsFilename), options: .atomic)
        try dmxPatchData.write(to: folder.appendingPathComponent(dmxPatchFilename), options: .atomic)
        try lightingCuesData.write(to: folder.appendingPathComponent(lightingCuesFilename), options: .atomic)
        try backdropCuesData.write(to: folder.appendingPathComponent(backdropCuesFilename), options: .atomic)
        try modulationData.write(to: folder.appendingPathComponent(modulationFilename), options: .atomic)
        try stageLayoutData.write(to: folder.appendingPathComponent(stageLayoutFilename), options: .atomic)
        try overlayCardsData.write(to: folder.appendingPathComponent(overlayCardsFilename), options: .atomic)
        let media = folder.appendingPathComponent(mediaDir, isDirectory: true)
        try FileManager.default.createDirectory(at: media, withIntermediateDirectories: true)
    }

    static func loadProject(from folder: URL) throws -> ShowProjectDocument {
        let data = try Data(contentsOf: folder.appendingPathComponent(projectFilename))
        return try JSONDecoder().decode(ShowProjectDocument.self, from: data)
    }

    static func loadScenes(from folder: URL) throws -> Data {
        try Data(contentsOf: folder.appendingPathComponent(scenesFilename))
    }

    static func loadSceneControls(from folder: URL) throws -> Data {
        try Data(contentsOf: folder.appendingPathComponent(sceneControlsFilename))
    }

    static func loadDMXPatch(from folder: URL) throws -> Data {
        try Data(contentsOf: folder.appendingPathComponent(dmxPatchFilename))
    }

    static func loadLightingCues(from folder: URL) throws -> Data {
        try Data(contentsOf: folder.appendingPathComponent(lightingCuesFilename))
    }

    static func loadBackdropCues(from folder: URL) throws -> Data {
        try Data(contentsOf: folder.appendingPathComponent(backdropCuesFilename))
    }

    static func loadModulation(from folder: URL) throws -> Data {
        try Data(contentsOf: folder.appendingPathComponent(modulationFilename))
    }

    static func loadStageLayout(from folder: URL) throws -> Data {
        try Data(contentsOf: folder.appendingPathComponent(stageLayoutFilename))
    }

    static func loadOverlayCards(from folder: URL) throws -> Data {
        try Data(contentsOf: folder.appendingPathComponent(overlayCardsFilename))
    }

    static func mediaDirectory(forPackage folder: URL) -> URL {
        folder.appendingPathComponent(mediaDir, isDirectory: true)
    }

    static func suggestedArchiveFilename(for project: ShowProjectDocument) -> String {
        let base = project.show.title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let sanitized = base.isEmpty ? "FSDMXVision-Show" : base
        return "\(sanitized).\(archiveExtension)"
    }

    /// Creates a zip archive from a saved package folder using `ditto`.
    static func exportArchive(from folder: URL, to archiveURL: URL) throws {
        let fm = FileManager.default
        let parent = archiveURL.deletingLastPathComponent()
        try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        if fm.fileExists(atPath: archiveURL.path) {
            try fm.removeItem(at: archiveURL)
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", folder.path, archiveURL.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "ShowProjectPackage", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: "Failed to export show package archive.",
            ])
        }
    }

    /// Extracts a `.cosmicshow.zip` archive and returns the detected package folder.
    static func importArchive(from archiveURL: URL, to extractionRoot: URL) throws -> URL {
        let fm = FileManager.default
        if fm.fileExists(atPath: extractionRoot.path) {
            try fm.removeItem(at: extractionRoot)
        }
        try fm.createDirectory(at: extractionRoot, withIntermediateDirectories: true)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", archiveURL.path, extractionRoot.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "ShowProjectPackage", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: "Failed to extract show package archive.",
            ])
        }
        return try findPackageRoot(in: extractionRoot)
    }

    private static func findPackageRoot(in extractionRoot: URL) throws -> URL {
        let marker = extractionRoot.appendingPathComponent(projectFilename)
        if FileManager.default.fileExists(atPath: marker.path) {
            return extractionRoot
        }
        let entries = try FileManager.default.contentsOfDirectory(at: extractionRoot, includingPropertiesForKeys: nil)
        for entry in entries {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: entry.path, isDirectory: &isDir), isDir.boolValue else { continue }
            let candidate = entry.appendingPathComponent(projectFilename)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return entry
            }
        }
        throw NSError(domain: "ShowProjectPackage", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Archive does not contain a valid show package (.cosmicshow.zip).",
        ])
    }
}

enum LastShowProjectBookmark {
    private static let key = AppIdentity.lastShowProjectFolderDefaultsKey

    static func save(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: key)
    }

    static func load() -> URL? {
        guard let p = UserDefaults.standard.string(forKey: key) else { return nil }
        return URL(fileURLWithPath: p, isDirectory: true)
    }
}
