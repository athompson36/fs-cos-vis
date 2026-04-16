import Foundation

struct OverlayAsset: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var filePath: String
    var opacity: Float
    var blendMode: String

    init(id: UUID = UUID(), name: String, filePath: String, opacity: Float = 1.0, blendMode: String = "screen") {
        self.id = id
        self.name = name
        self.filePath = filePath
        self.opacity = opacity
        self.blendMode = blendMode
    }
}
