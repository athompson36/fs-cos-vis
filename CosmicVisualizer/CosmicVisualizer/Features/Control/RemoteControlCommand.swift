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

    init(
        type: String,
        sceneID: UUID? = nil,
        index: Int? = nil,
        bpm: Double? = nil,
        source: String? = nil,
        fractalZoom: Float? = nil,
        liquidTurbulence: Float? = nil,
        compositeBlend: Float? = nil,
        enabled: Bool? = nil,
        port: Int? = nil,
        bindLAN: Bool? = nil,
        authToken: String? = nil,
        serialPath: String? = nil,
        midiInputUID: String? = nil,
        sceneOrder: [UUID]? = nil,
        paletteID: UUID? = nil,
        liquidFocus: Float? = nil,
        fractalAppearance: Float? = nil,
        overlayFractalFusion: Float? = nil
    ) {
        self.type = type
        self.sceneID = sceneID
        self.index = index
        self.bpm = bpm
        self.source = source
        self.fractalZoom = fractalZoom
        self.liquidTurbulence = liquidTurbulence
        self.compositeBlend = compositeBlend
        self.enabled = enabled
        self.port = port
        self.bindLAN = bindLAN
        self.authToken = authToken
        self.serialPath = serialPath
        self.midiInputUID = midiInputUID
        self.sceneOrder = sceneOrder
        self.paletteID = paletteID
        self.liquidFocus = liquidFocus
        self.fractalAppearance = fractalAppearance
        self.overlayFractalFusion = overlayFractalFusion
    }
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
