import Foundation

struct VisualizationScene: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    /// Legacy catalog string (e.g. `"julia"`, `"mandelbrot"`). Rendering uses `SceneEditState.layer.fractalGeometryIndex`; when that index is default `0` and this string contains `"mandel"`, the app upgrades to Mandelbrot geometry on load.
    var fractalMode: String
    var liquidLightEnabled: Bool
    var paletteID: UUID?
    var overlayIDs: [UUID]

    init(
        id: UUID = UUID(),
        name: String,
        fractalMode: String,
        liquidLightEnabled: Bool,
        paletteID: UUID? = nil,
        overlayIDs: [UUID] = []
    ) {
        self.id = id
        self.name = name
        self.fractalMode = fractalMode
        self.liquidLightEnabled = liquidLightEnabled
        self.paletteID = paletteID
        self.overlayIDs = overlayIDs
    }
}
