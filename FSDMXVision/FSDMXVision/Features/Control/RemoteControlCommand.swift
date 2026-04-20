import Foundation

/// Wire/API command envelope decoded from JSON (`POST /api/command` and MIDI map).
struct RemoteControlCommand: Codable, Equatable, Sendable {
    var type: String
    var sceneID: UUID? = nil
    var index: Int? = nil
    var bpm: Double? = nil
    var source: String? = nil
    var fractalZoom: Float? = nil
    var liquidTurbulence: Float? = nil
    var compositeBlend: Float? = nil
    var enabled: Bool? = nil
    var port: Int? = nil
    var bindLAN: Bool? = nil
    var authToken: String? = nil
    var serialPath: String? = nil
    var midiInputUID: String? = nil
    var sceneOrder: [UUID]? = nil
    var paletteID: UUID? = nil
    var liquidFocus: Float? = nil
    var fractalAppearance: Float? = nil
    var overlayFractalFusion: Float? = nil
    var fractalExplore: Float? = nil
    var fractalExploreSpeed: Float? = nil
    var fractalIterBoost: Float? = nil
    var dyeMix: Float? = nil
    var fractalSmoothShading: Float? = nil
    var compositeBloomStrength: Float? = nil
    var compositeVignetteStrength: Float? = nil
    var liquidReconstituteAmount: Float? = nil
    var liquidReconstituteRate: Float? = nil
    /// Composite Milkdrop-style spectrum UV warp (0…1). See `SetSpectrumWarpAmount`.
    var spectrumWarpAmount: Float? = nil
}

final class ControlCommandHub {
    unowned let model: AppModel

    init(model: AppModel) {
        self.model = model
    }

    func apply(_ command: RemoteControlCommand) {
        model.applyRemoteCommand(command)
    }

    static func decode(from data: Data) throws -> RemoteControlCommand {
        try JSONDecoder().decode(RemoteControlCommand.self, from: data)
    }
}
