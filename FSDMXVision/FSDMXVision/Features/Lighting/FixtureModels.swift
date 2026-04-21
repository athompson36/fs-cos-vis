import Foundation

/// Semantic role for a DMX channel in a fixture profile.
enum FixtureChannelRole: String, Codable, CaseIterable, Sendable {
    case intensity
    case red
    case green
    case blue
    case white
    case amber
    case uv
    case strobe
    case pan
    case tilt
    /// Fog / haze volume output (typ. channel 1 on hazers).
    case hazeOutput
    case hazeFan
    case hazePump
    case generic
}

struct FixtureChannelDef: Codable, Equatable, Hashable, Sendable {
    var label: String
    var role: FixtureChannelRole
}

struct FixtureProfile: Codable, Equatable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var channels: [FixtureChannelDef]
    /// Open Fixture Library path key, e.g. `cameo/hydrabeam-400`.
    var oflFixtureKey: String?
    var oflModeName: String?
    /// Parallel to `channels` when imported from OFL (capability / fine channel labels).
    var channelCapabilities: [String]?

    init(
        id: UUID = UUID(),
        name: String,
        channels: [FixtureChannelDef],
        oflFixtureKey: String? = nil,
        oflModeName: String? = nil,
        channelCapabilities: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.channels = channels
        self.oflFixtureKey = oflFixtureKey
        self.oflModeName = oflModeName
        self.channelCapabilities = channelCapabilities
    }

    static func builtInLegacyVisualization() -> FixtureProfile {
        FixtureProfile(
            name: "Legacy visualization (5 ch)",
            channels: [
                FixtureChannelDef(label: "Scene index", role: .generic),
                FixtureChannelDef(label: "Fractal zoom", role: .generic),
                FixtureChannelDef(label: "Liquid turbulence", role: .generic),
                FixtureChannelDef(label: "Composite blend", role: .generic),
                FixtureChannelDef(label: "BPM", role: .generic),
            ]
        )
    }

    static func builtInRGBPar() -> FixtureProfile {
        FixtureProfile(
            name: "RGB Par (dim + RGB)",
            channels: [
                FixtureChannelDef(label: "Dimmer", role: .intensity),
                FixtureChannelDef(label: "Red", role: .red),
                FixtureChannelDef(label: "Green", role: .green),
                FixtureChannelDef(label: "Blue", role: .blue),
            ]
        )
    }

    /// RGBW + amber + UV + strobe (common LED wash).
    static func builtInRGBWAStrobe() -> FixtureProfile {
        FixtureProfile(
            name: "RGBW + amber + UV + strobe",
            channels: [
                FixtureChannelDef(label: "Dimmer", role: .intensity),
                FixtureChannelDef(label: "Red", role: .red),
                FixtureChannelDef(label: "Green", role: .green),
                FixtureChannelDef(label: "Blue", role: .blue),
                FixtureChannelDef(label: "White", role: .white),
                FixtureChannelDef(label: "Amber", role: .amber),
                FixtureChannelDef(label: "UV", role: .uv),
                FixtureChannelDef(label: "Strobe", role: .strobe),
            ]
        )
    }

    /// Typical compact hazer / fog machine (output + fan + pump).
    static func builtInFogMachine() -> FixtureProfile {
        FixtureProfile(
            name: "Fog / haze (3 ch)",
            channels: [
                FixtureChannelDef(label: "Haze / fog output", role: .hazeOutput),
                FixtureChannelDef(label: "Fan speed", role: .hazeFan),
                FixtureChannelDef(label: "Pump / fluid", role: .hazePump),
            ]
        )
    }
}

struct FixtureInstance: Codable, Equatable, Identifiable, Hashable, Sendable {
    var id: UUID
    var profileID: UUID
    /// Only universe 0 is output on USB OpenDMX in v1.
    var universe: UInt8
    /// 1...512
    var startAddress: Int
    /// Channel index in profile (0-based) -> DMX value.
    var manualValues: [String: UInt8]
    /// Optional per-patch labels (keys `"0"`…`"n"`) overriding `FixtureProfile` channel names for this rig instance (e.g. dimmer pack output usage).
    var channelLabelOverrides: [String: String]?
    /// Free-text rig note for this patch row (e.g. Hurricane Haze + DP-415R wiring).
    var rigNote: String?

    init(
        id: UUID = UUID(),
        profileID: UUID,
        universe: UInt8 = 0,
        startAddress: Int,
        manualValues: [String: UInt8] = [:],
        channelLabelOverrides: [String: String]? = nil,
        rigNote: String? = nil
    ) {
        self.id = id
        self.profileID = profileID
        self.universe = universe
        self.startAddress = startAddress
        self.manualValues = manualValues
        self.channelLabelOverrides = channelLabelOverrides
        self.rigNote = rigNote
    }

    /// Effective UI label for a profile channel, honoring optional per-instance overrides.
    func resolvedChannelLabel(channelIndex idx: Int, profile: FixtureProfile) -> String {
        if let o = channelLabelOverrides?[String(idx)]?.trimmingCharacters(in: .whitespacesAndNewlines), !o.isEmpty {
            return o
        }
        guard profile.channels.indices.contains(idx) else { return "Ch \(idx)" }
        return profile.channels[idx].label
    }

    func manual(forChannelIndex idx: Int) -> UInt8 {
        manualValues[String(idx)] ?? 0
    }

    mutating func setManual(channelIndex idx: Int, value: UInt8) {
        manualValues[String(idx)] = value
    }
}

/// Root patch document: fixture library + instances on the rig.
struct DMXPatchDocument: Codable, Equatable, Sendable {
    var version: Int
    /// When true, channels 1–5 mirror the original visualization mapping (single-universe USB).
    var useLegacyVisualizationSlots: Bool
    var profiles: [FixtureProfile]
    var instances: [FixtureInstance]

    static let currentVersion = 1

    init(
        version: Int = DMXPatchDocument.currentVersion,
        useLegacyVisualizationSlots: Bool = true,
        profiles: [FixtureProfile] = [],
        instances: [FixtureInstance] = []
    ) {
        self.version = version
        self.useLegacyVisualizationSlots = useLegacyVisualizationSlots
        self.profiles = profiles
        self.instances = instances
    }

    static func `default`() -> DMXPatchDocument {
        let legacy = FixtureProfile.builtInLegacyVisualization()
        let rgb = FixtureProfile.builtInRGBPar()
        let rgbwa = FixtureProfile.builtInRGBWAStrobe()
        let fog = FixtureProfile.builtInFogMachine()
        return DMXPatchDocument(
            useLegacyVisualizationSlots: true,
            profiles: [legacy, rgb, rgbwa, fog],
            instances: []
        )
    }

    func profile(id: UUID) -> FixtureProfile? {
        profiles.first { $0.id == id }
    }
}

// MARK: - Roadmap (QLC / OLA-class features)

/// Placeholder for phased DMX work (Art-Net, sACN, RDM, chasers, matrix). USB OpenDMX universe 0 remains the shipping output path.
enum DMXFeatureRoadmap: String, Sendable {
    case artNetSacnMultiUniverse
    case rdmDiscovery
    case chaserSequences
    case ledMatrixPixelMap
    case incomingDmxInput
}
