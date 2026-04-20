import Foundation

/// Named blend modes for overlays (GPU path can map these to `MTLBlendOperation`).
enum OverlayBlendMode: String, CaseIterable, Codable {
    case screen
    case add
    case multiply
    case softLight
}
