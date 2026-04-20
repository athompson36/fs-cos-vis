import Foundation

enum ModulatorKind: String, Codable, CaseIterable, Sendable {
    case lfoSine
    case lfoTriangle
    case tempoPulse
    case audioBandLow
    case audioBandMid
    case audioBandHigh
}

struct ModulatorDefinition: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var enabled: Bool
    /// DMX channel 1...512
    var targetChannel: Int
    var kind: ModulatorKind
    /// Depth of modulation as fraction of full scale (0...1).
    var depth: Float
    /// Rate in Hz for LFO; ignored for tempo/audio.
    var rateHz: Float
    /// Smoothing 0...1 (higher = slower follow for audio).
    var smoothing: Float
    /// Tempo divisions for tempoPulse (beats per pulse period).
    var tempoDivisions: Float

    init(
        id: UUID = UUID(),
        name: String = "Modulator",
        enabled: Bool = true,
        targetChannel: Int = 1,
        kind: ModulatorKind = .lfoSine,
        depth: Float = 0.5,
        rateHz: Float = 0.25,
        smoothing: Float = 0.35,
        tempoDivisions: Float = 1
    ) {
        self.id = id
        self.name = name
        self.enabled = enabled
        self.targetChannel = targetChannel
        self.kind = kind
        self.depth = depth
        self.rateHz = rateHz
        self.smoothing = smoothing
        self.tempoDivisions = tempoDivisions
    }
}

struct ModulationDocument: Codable, Equatable, Sendable {
    var version: Int
    var modulators: [ModulatorDefinition]

    static let currentVersion = 1

    init(version: Int = currentVersion, modulators: [ModulatorDefinition] = []) {
        self.version = version
        self.modulators = modulators
    }

    static func `default`() -> ModulationDocument {
        // Empty by default so legacy visualization channels 1–5 stay untouched until the user adds modulators.
        ModulationDocument(modulators: [])
    }
}

enum ModulationStore {
    private static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent(AppIdentity.applicationSupportFolderName, isDirectory: true)
            .appendingPathComponent("modulation.json")
    }

    static func loadOrDefault() -> ModulationDocument {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let doc = try? JSONDecoder().decode(ModulationDocument.self, from: data)
        else {
            return ModulationDocument.default()
        }
        return doc
    }

    static func save(_ doc: ModulationDocument) throws {
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(doc)
        try data.write(to: fileURL, options: .atomic)
    }
}
