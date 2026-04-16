import Foundation

/// `POST /api/scenes/reorder` body.
struct ReorderScenesBody: Codable, Equatable, Sendable {
    var sceneOrder: [UUID]
}
