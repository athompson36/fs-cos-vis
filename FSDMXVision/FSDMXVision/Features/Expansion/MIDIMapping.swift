import Foundation

/// Maps MIDI CC to remote command types (JSON-serializable for future file override).
struct MIDIMapping: Codable, Equatable, Sendable {
    struct CCMap: Codable, Equatable, Sendable {
        var channel: Int
        var controller: Int
        var commandType: String
    }

    /// Continuous layer parameters (CC → float commands).
    struct ContinuousCCMap: Codable, Equatable, Sendable {
        var parameterID: String
        var channel: Int
        var controller: Int
    }

    enum CodingKeys: String, CodingKey {
        case cc
        case continuousCC
    }

    var cc: [CCMap]
    var continuousCC: [ContinuousCCMap]

    init(cc: [CCMap], continuousCC: [ContinuousCCMap] = []) {
        self.cc = cc
        self.continuousCC = continuousCC
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cc = try c.decode([CCMap].self, forKey: .cc)
        continuousCC = try c.decodeIfPresent([ContinuousCCMap].self, forKey: .continuousCC) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(cc, forKey: .cc)
        try c.encode(continuousCC, forKey: .continuousCC)
    }

    static func `default`() -> MIDIMapping {
        MIDIMapping(
            cc: [
                CCMap(channel: 0, controller: 20, commandType: "NextScene"),
                CCMap(channel: 0, controller: 21, commandType: "PreviousScene"),
                CCMap(channel: 0, controller: 22, commandType: "RandomScene"),
                CCMap(channel: 0, controller: 23, commandType: "TapTempo"),
                CCMap(channel: 0, controller: 24, commandType: "NextLightingCue"),
                CCMap(channel: 0, controller: 25, commandType: "PreviousLightingCue"),
            ],
            continuousCC: defaultContinuousPresets()
        )
    }

    /// Legacy CC1/CC2 fractal zoom / liquid turbulence (same as previous hardcoded `AppModel` behavior).
    static func defaultContinuousPresets() -> [ContinuousCCMap] {
        [
            ContinuousCCMap(parameterID: LayerControlParameter.fractalZoom.rawValue, channel: 0, controller: 1),
            ContinuousCCMap(parameterID: LayerControlParameter.liquidTurbulence.rawValue, channel: 0, controller: 2),
            ContinuousCCMap(parameterID: LayerControlParameter.compositeBlend.rawValue, channel: 0, controller: 3),
            ContinuousCCMap(parameterID: LayerControlParameter.fractalExplore.rawValue, channel: 0, controller: 4),
            ContinuousCCMap(parameterID: LayerControlParameter.fractalExploreSpeed.rawValue, channel: 0, controller: 5),
            ContinuousCCMap(parameterID: LayerControlParameter.fractalIterBoost.rawValue, channel: 0, controller: 6),
            ContinuousCCMap(parameterID: LayerControlParameter.zoomEffectType.rawValue, channel: 0, controller: 7),
            ContinuousCCMap(parameterID: LayerControlParameter.liquidReconstituteAmount.rawValue, channel: 0, controller: 8),
            ContinuousCCMap(parameterID: LayerControlParameter.liquidReconstituteRate.rawValue, channel: 0, controller: 9),
            ContinuousCCMap(parameterID: LayerControlParameter.dyeMix.rawValue, channel: 0, controller: 10),
            ContinuousCCMap(parameterID: LayerControlParameter.fractalSmoothShading.rawValue, channel: 0, controller: 11),
            ContinuousCCMap(parameterID: LayerControlParameter.compositeBloomStrength.rawValue, channel: 0, controller: 12),
            ContinuousCCMap(parameterID: LayerControlParameter.compositeVignetteStrength.rawValue, channel: 0, controller: 13),
            ContinuousCCMap(parameterID: LayerControlParameter.liquidFocus.rawValue, channel: 0, controller: 14),
            ContinuousCCMap(parameterID: LayerControlParameter.fractalAppearance.rawValue, channel: 0, controller: 15),
            ContinuousCCMap(parameterID: LayerControlParameter.overlayFractalFusion.rawValue, channel: 0, controller: 16),
        ]
    }

    func command(forChannel channel: Int, controller: Int) -> RemoteControlCommand? {
        guard let hit = cc.first(where: { $0.channel == channel && $0.controller == controller }) else { return nil }
        return RemoteControlCommand(type: hit.commandType)
    }

    func layerParameter(forChannel channel: Int, controller: Int) -> LayerControlParameter? {
        guard let hit = continuousCC.first(where: { $0.channel == channel && $0.controller == controller }) else { return nil }
        return LayerControlParameter(parameterID: hit.parameterID)
    }

    /// Replace mapping for `parameter`, and clear any other parameter using the same `(channel, controller)`.
    mutating func learnContinuous(parameter: LayerControlParameter, channel: Int, controller: Int) {
        continuousCC.removeAll { $0.parameterID == parameter.rawValue }
        continuousCC.removeAll { $0.channel == channel && $0.controller == controller }
        continuousCC.append(ContinuousCCMap(parameterID: parameter.rawValue, channel: channel, controller: controller))
    }
}
