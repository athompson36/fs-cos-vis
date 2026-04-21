import Foundation

enum ModulatorKind: String, Codable, CaseIterable, Sendable {
    case lfoSine
    case lfoTriangle
    case tempoPulse
    case audioBandLow
    case audioBandMid
    case audioBandHigh
    /// Drives hue through HSV-style conversion into fixture R/G/B channels (roles `.red`/`.green`/`.blue`).
    case hsiHueSweep
}

struct ModulatorDefinition: Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var enabled: Bool
    /// DMX channel 1...512 (legacy / fallback when fixture fields are unset).
    var targetChannel: Int
    var kind: ModulatorKind
    /// Depth of modulation as fraction of full scale (0...1).
    var depth: Float
    /// Rate in Hz for LFO; ignored for tempo/audio/HSI hue uses same clock as LFO for hue spin when not audio-driven.
    var rateHz: Float
    /// Smoothing 0...1 (higher = slower follow for audio).
    var smoothing: Float
    /// Tempo divisions for tempoPulse (beats per pulse period).
    var tempoDivisions: Float
    /// When set with `targetChannelIndexInProfile`, modulation targets this fixture channel regardless of address changes.
    var targetFixtureInstanceID: UUID?
    /// 0-based index into `FixtureProfile.channels`.
    var targetChannelIndexInProfile: Int?
    /// Saturation 0...1 for `hsiHueSweep` (HSV-style saturation).
    var hsiSaturation: Float
    /// Brightness 0...1 for `hsiHueSweep` (HSV V / intensity).
    var hsiIntensity: Float

    init(
        id: UUID = UUID(),
        name: String = "Modulator",
        enabled: Bool = true,
        targetChannel: Int = 1,
        kind: ModulatorKind = .lfoSine,
        depth: Float = 0.5,
        rateHz: Float = 0.25,
        smoothing: Float = 0.35,
        tempoDivisions: Float = 1,
        targetFixtureInstanceID: UUID? = nil,
        targetChannelIndexInProfile: Int? = nil,
        hsiSaturation: Float = 1,
        hsiIntensity: Float = 1
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
        self.targetFixtureInstanceID = targetFixtureInstanceID
        self.targetChannelIndexInProfile = targetChannelIndexInProfile
        self.hsiSaturation = hsiSaturation
        self.hsiIntensity = hsiIntensity
    }
}

extension ModulatorDefinition: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, enabled, targetChannel, kind, depth, rateHz, smoothing, tempoDivisions
        case targetFixtureInstanceID, targetChannelIndexInProfile, hsiSaturation, hsiIntensity
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Modulator"
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        targetChannel = try c.decodeIfPresent(Int.self, forKey: .targetChannel) ?? 1
        kind = try c.decodeIfPresent(ModulatorKind.self, forKey: .kind) ?? .lfoSine
        depth = try c.decodeIfPresent(Float.self, forKey: .depth) ?? 0.5
        rateHz = try c.decodeIfPresent(Float.self, forKey: .rateHz) ?? 0.25
        smoothing = try c.decodeIfPresent(Float.self, forKey: .smoothing) ?? 0.35
        tempoDivisions = try c.decodeIfPresent(Float.self, forKey: .tempoDivisions) ?? 1
        targetFixtureInstanceID = try c.decodeIfPresent(UUID.self, forKey: .targetFixtureInstanceID)
        targetChannelIndexInProfile = try c.decodeIfPresent(Int.self, forKey: .targetChannelIndexInProfile)
        hsiSaturation = try c.decodeIfPresent(Float.self, forKey: .hsiSaturation) ?? 1
        hsiIntensity = try c.decodeIfPresent(Float.self, forKey: .hsiIntensity) ?? 1
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(enabled, forKey: .enabled)
        try c.encode(targetChannel, forKey: .targetChannel)
        try c.encode(kind, forKey: .kind)
        try c.encode(depth, forKey: .depth)
        try c.encode(rateHz, forKey: .rateHz)
        try c.encode(smoothing, forKey: .smoothing)
        try c.encode(tempoDivisions, forKey: .tempoDivisions)
        try c.encodeIfPresent(targetFixtureInstanceID, forKey: .targetFixtureInstanceID)
        try c.encodeIfPresent(targetChannelIndexInProfile, forKey: .targetChannelIndexInProfile)
        try c.encode(hsiSaturation, forKey: .hsiSaturation)
        try c.encode(hsiIntensity, forKey: .hsiIntensity)
    }
}

struct ModulationDocument: Codable, Equatable, Sendable {
    var version: Int
    var modulators: [ModulatorDefinition]

    static let currentVersion = 2

    init(version: Int = currentVersion, modulators: [ModulatorDefinition] = []) {
        self.version = version
        self.modulators = modulators
    }

    static func `default`() -> ModulationDocument {
        ModulationDocument(modulators: [])
    }
}

extension ModulatorKind {
    /// Short labels for the modulation UI (distinct from `rawValue`).
    var displayTitle: String {
        switch self {
        case .lfoSine: return "LFO · sine"
        case .lfoTriangle: return "LFO · triangle"
        case .tempoPulse: return "Tempo pulse"
        case .audioBandLow: return "Audio · low"
        case .audioBandMid: return "Audio · mid"
        case .audioBandHigh: return "Audio · high"
        case .hsiHueSweep: return "HSI hue sweep (RGB)"
        }
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
