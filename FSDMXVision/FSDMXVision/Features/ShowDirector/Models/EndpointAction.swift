import Foundation

enum EndpointAction: Equatable, Sendable {
    case recallLightingScene(id: String, sceneID: String, fadeMilliseconds: Int)
    case applyPalette(id: String, paletteID: String, fadeMilliseconds: Int)
    case playBackdropClip(id: String, clipID: String, transition: String, loop: Bool)
    case addOBSMarker(id: String, label: String)
    case recallVisualScene(id: String, sceneID: String, fadeMilliseconds: Int)
    case showOverlay(id: String, overlayID: String)
    case hideAllOverlays(id: String)
    case startRecording(id: String, namingTemplate: String?)
    case stopRecording(id: String)
    case blackoutLighting(id: String)
    case blackoutVideo(id: String)
    case restoreSafeLook(id: String)

    var id: String {
        switch self {
        case .recallLightingScene(let id, _, _),
             .applyPalette(let id, _, _),
             .playBackdropClip(let id, _, _, _),
             .addOBSMarker(let id, _),
             .recallVisualScene(let id, _, _),
             .showOverlay(let id, _),
             .hideAllOverlays(let id),
             .startRecording(let id, _),
             .stopRecording(let id),
             .blackoutLighting(let id),
             .blackoutVideo(let id),
             .restoreSafeLook(let id):
            return id
        }
    }

    var endpointKind: ShowEndpointKind {
        switch self {
        case .recallLightingScene, .blackoutLighting:
            return .lighting
        case .applyPalette:
            return .palette
        case .playBackdropClip, .blackoutVideo:
            return .backdropVideo
        case .addOBSMarker:
            return .obs
        case .recallVisualScene:
            return .visuals
        case .showOverlay, .hideAllOverlays:
            return .overlay
        case .startRecording, .stopRecording:
            return .recording
        case .restoreSafeLook:
            return .utility
        }
    }

    var typeName: String {
        switch self {
        case .recallLightingScene: return "recallScene"
        case .applyPalette: return "applyPalette"
        case .playBackdropClip: return "playClip"
        case .addOBSMarker: return "addMarker"
        case .recallVisualScene: return "recallScene"
        case .showOverlay: return "showOverlay"
        case .hideAllOverlays: return "hideAllOverlays"
        case .startRecording: return "startRecording"
        case .stopRecording: return "stopRecording"
        case .blackoutLighting: return "blackoutLighting"
        case .blackoutVideo: return "blackoutVideo"
        case .restoreSafeLook: return "restoreSafeLook"
        }
    }
}

enum EndpointActionDecodingError: Error, LocalizedError, Equatable {
    case unsupportedCombination(endpoint: String, type: String)
    case missingField(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedCombination(let endpoint, let type):
            return "Unsupported version-1 EndpointAction combination endpoint=\(endpoint) type=\(type)."
        case .missingField(let field):
            return "EndpointAction is missing required field \"\(field)\"."
        }
    }
}

extension EndpointAction: Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case endpoint
        case type
        case sceneID = "sceneId"
        case fadeMilliseconds = "fadeMs"
        case paletteID = "paletteId"
        case clipID = "clipId"
        case transition
        case loop
        case label
        case overlayID = "overlayId"
        case namingTemplate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let id = try c.decode(String.self, forKey: .id)
        let endpoint = try c.decode(String.self, forKey: .endpoint)
        let type = try c.decode(String.self, forKey: .type)

        switch (endpoint, type) {
        case ("lighting", "recallScene"):
            self = .recallLightingScene(
                id: id,
                sceneID: try c.decode(String.self, forKey: .sceneID),
                fadeMilliseconds: try c.decode(Int.self, forKey: .fadeMilliseconds)
            )
        case ("palette", "applyPalette"):
            self = .applyPalette(
                id: id,
                paletteID: try c.decode(String.self, forKey: .paletteID),
                fadeMilliseconds: try c.decode(Int.self, forKey: .fadeMilliseconds)
            )
        case ("backdropVideo", "playClip"):
            self = .playBackdropClip(
                id: id,
                clipID: try c.decode(String.self, forKey: .clipID),
                transition: try c.decode(String.self, forKey: .transition),
                loop: try c.decode(Bool.self, forKey: .loop)
            )
        case ("obs", "addMarker"):
            self = .addOBSMarker(
                id: id,
                label: try c.decode(String.self, forKey: .label)
            )
        case ("visuals", "recallScene"):
            self = .recallVisualScene(
                id: id,
                sceneID: try c.decode(String.self, forKey: .sceneID),
                fadeMilliseconds: try c.decode(Int.self, forKey: .fadeMilliseconds)
            )
        case ("overlay", "showOverlay"):
            self = .showOverlay(
                id: id,
                overlayID: try c.decode(String.self, forKey: .overlayID)
            )
        case ("overlay", "hideAllOverlays"):
            self = .hideAllOverlays(id: id)
        case ("recording", "startRecording"):
            self = .startRecording(
                id: id,
                namingTemplate: try c.decodeIfPresent(String.self, forKey: .namingTemplate)
            )
        case ("recording", "stopRecording"):
            self = .stopRecording(id: id)
        case ("lighting", "blackoutLighting"):
            self = .blackoutLighting(id: id)
        case ("backdropVideo", "blackoutVideo"):
            self = .blackoutVideo(id: id)
        case ("utility", "restoreSafeLook"):
            self = .restoreSafeLook(id: id)
        default:
            throw EndpointActionDecodingError.unsupportedCombination(endpoint: endpoint, type: type)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(endpointKind.rawValue, forKey: .endpoint)
        try c.encode(typeName, forKey: .type)

        switch self {
        case .recallLightingScene(_, let sceneID, let fadeMilliseconds),
             .recallVisualScene(_, let sceneID, let fadeMilliseconds):
            try c.encode(sceneID, forKey: .sceneID)
            try c.encode(fadeMilliseconds, forKey: .fadeMilliseconds)
        case .applyPalette(_, let paletteID, let fadeMilliseconds):
            try c.encode(paletteID, forKey: .paletteID)
            try c.encode(fadeMilliseconds, forKey: .fadeMilliseconds)
        case .playBackdropClip(_, let clipID, let transition, let loop):
            try c.encode(clipID, forKey: .clipID)
            try c.encode(transition, forKey: .transition)
            try c.encode(loop, forKey: .loop)
        case .addOBSMarker(_, let label):
            try c.encode(label, forKey: .label)
        case .showOverlay(_, let overlayID):
            try c.encode(overlayID, forKey: .overlayID)
        case .startRecording(_, let namingTemplate):
            try c.encodeIfPresent(namingTemplate, forKey: .namingTemplate)
        case .hideAllOverlays, .stopRecording, .blackoutLighting, .blackoutVideo, .restoreSafeLook:
            break
        }
    }
}
