import Foundation

enum ShowDirectorEndpointControlError: Error, LocalizedError, Equatable {
    case targetNotFound(endpoint: ShowEndpointKind, id: UUID)
    case verificationFailed(endpoint: ShowEndpointKind, id: UUID)
    case persistenceFailed(endpoint: ShowEndpointKind, message: String)

    var errorDescription: String? {
        switch self {
        case .targetNotFound(let endpoint, let id):
            return "The \(endpoint.rawValue) target \(id.uuidString) is not available."
        case .verificationFailed(let endpoint, let id):
            return "The \(endpoint.rawValue) target \(id.uuidString) did not become active after recall."
        case .persistenceFailed(let endpoint, let message):
            return "The \(endpoint.rawValue) change could not be saved: \(message)"
        }
    }
}

@MainActor
protocol VisualSceneControlling: AnyObject, Sendable {
    func visualSceneIDs() -> [UUID]
    func activeVisualSceneID() -> UUID?
    func recallVisualScene(id: UUID) throws
}

@MainActor
protocol PaletteControlling: AnyObject, Sendable {
    func paletteIDs() -> [UUID]
    func activePaletteID() -> UUID?
    func selectPalette(id: UUID) throws
}

@MainActor
protocol LightingCueControlling: AnyObject, Sendable {
    func lightingCueIDs() -> [UUID]
    func activeLightingCueID() -> UUID?
    func recallLightingCue(id: UUID) throws
    func lightingCueFadeSeconds(id: UUID) -> Double?
}
