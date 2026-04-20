import Foundation

struct LiquidDropperPalette: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var layers: [SceneEditState.LayerControls.LiquidDropperLayer]

    init(
        id: UUID = UUID(),
        name: String,
        layers: [SceneEditState.LayerControls.LiquidDropperLayer]
    ) {
        self.id = id
        self.name = name
        self.layers = Array(layers.prefix(SceneEditState.LayerControls.maxDropperLayers))
    }
}
