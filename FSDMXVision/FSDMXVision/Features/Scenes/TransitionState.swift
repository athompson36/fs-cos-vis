import Foundation

/// Simple scene cross-fade progress for UI and future GPU transitions.
enum TransitionState: Equatable, Codable {
    case idle
    case transitioning(fromSceneID: UUID, toSceneID: UUID, progress: Float)

    var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }

    mutating func advance(by delta: Float) {
        guard case .transitioning(let from, let to, let p) = self else { return }
        let next = min(1, p + delta)
        if next >= 1 {
            self = .idle
        } else {
            self = .transitioning(fromSceneID: from, toSceneID: to, progress: next)
        }
    }
}
