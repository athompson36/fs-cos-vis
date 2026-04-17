import Foundation

/// Semantic role for a DMX channel in a fixture profile.
enum FixtureChannelRole: String, Codable, CaseIterable, Sendable {
    case intensity
    case red
    case green
    case blue
    case pan
    case tilt
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

    init(id: UUID = UUID(), name: String, channels: [FixtureChannelDef]) {
        self.id = id
        self.name = name
        self.channels = channels
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

    init(
        id: UUID = UUID(),
        profileID: UUID,
        universe: UInt8 = 0,
        startAddress: Int,
        manualValues: [String: UInt8] = [:]
    ) {
        self.id = id
        self.profileID = profileID
        self.universe = universe
        self.startAddress = startAddress
        self.manualValues = manualValues
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
        return DMXPatchDocument(
            useLegacyVisualizationSlots: true,
            profiles: [legacy, rgb],
            instances: []
        )
    }

    func profile(id: UUID) -> FixtureProfile? {
        profiles.first { $0.id == id }
    }
}
