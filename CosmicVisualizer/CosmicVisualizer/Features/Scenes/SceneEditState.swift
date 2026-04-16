import Foundation

/// Authoring controls for a single scene (persisted separately from `VisualizationScene` identity).
struct SceneEditState: Codable, Equatable, Hashable {
    struct LayerControls: Codable, Equatable, Hashable {
        var fractalZoom: Float = 1
        var fractalColorSpeed: Float = 1
        var liquidTurbulence: Float = 1
        var compositeBlend: Float = 0.65
        /// 0 = soft / fuzzy liquid colors, 1 = sharper, more defined blobs.
        var liquidFocus: Float = 0.78
        /// 0 = palette-driven gradient fractal, 1 = deep cosmic + neon wireframe.
        var fractalAppearance: Float = 0
        /// How strongly overlay alpha follows fractal / liquid structure (seamless dissolve).
        var overlayFractalFusion: Float = 0.45
        /// Normalized overlay quad (bottom-left origin, y up): min X, min Y, width, height in 0…1.
        var overlayRectMinX: Float = 0
        var overlayRectMinY: Float = 0
        var overlayRectWidth: Float = 1
        var overlayRectHeight: Float = 1

        enum CodingKeys: String, CodingKey {
            case fractalZoom
            case fractalColorSpeed
            case liquidTurbulence
            case compositeBlend
            case liquidFocus
            case fractalAppearance
            case overlayFractalFusion
            case overlayRectMinX
            case overlayRectMinY
            case overlayRectWidth
            case overlayRectHeight
        }

        init(
            fractalZoom: Float = 1,
            fractalColorSpeed: Float = 1,
            liquidTurbulence: Float = 1,
            compositeBlend: Float = 0.65,
            liquidFocus: Float = 0.78,
            fractalAppearance: Float = 0,
            overlayFractalFusion: Float = 0.45,
            overlayRectMinX: Float = 0,
            overlayRectMinY: Float = 0,
            overlayRectWidth: Float = 1,
            overlayRectHeight: Float = 1
        ) {
            self.fractalZoom = fractalZoom
            self.fractalColorSpeed = fractalColorSpeed
            self.liquidTurbulence = liquidTurbulence
            self.compositeBlend = compositeBlend
            self.liquidFocus = liquidFocus
            self.fractalAppearance = fractalAppearance
            self.overlayFractalFusion = overlayFractalFusion
            self.overlayRectMinX = overlayRectMinX
            self.overlayRectMinY = overlayRectMinY
            self.overlayRectWidth = overlayRectWidth
            self.overlayRectHeight = overlayRectHeight
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            fractalZoom = try c.decodeIfPresent(Float.self, forKey: .fractalZoom) ?? 1
            fractalColorSpeed = try c.decodeIfPresent(Float.self, forKey: .fractalColorSpeed) ?? 1
            liquidTurbulence = try c.decodeIfPresent(Float.self, forKey: .liquidTurbulence) ?? 1
            compositeBlend = try c.decodeIfPresent(Float.self, forKey: .compositeBlend) ?? 0.65
            liquidFocus = try c.decodeIfPresent(Float.self, forKey: .liquidFocus) ?? 0.78
            fractalAppearance = try c.decodeIfPresent(Float.self, forKey: .fractalAppearance) ?? 0
            overlayFractalFusion = try c.decodeIfPresent(Float.self, forKey: .overlayFractalFusion) ?? 0.45
            overlayRectMinX = try c.decodeIfPresent(Float.self, forKey: .overlayRectMinX) ?? 0
            overlayRectMinY = try c.decodeIfPresent(Float.self, forKey: .overlayRectMinY) ?? 0
            overlayRectWidth = try c.decodeIfPresent(Float.self, forKey: .overlayRectWidth) ?? 1
            overlayRectHeight = try c.decodeIfPresent(Float.self, forKey: .overlayRectHeight) ?? 1
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(fractalZoom, forKey: .fractalZoom)
            try c.encode(fractalColorSpeed, forKey: .fractalColorSpeed)
            try c.encode(liquidTurbulence, forKey: .liquidTurbulence)
            try c.encode(compositeBlend, forKey: .compositeBlend)
            try c.encode(liquidFocus, forKey: .liquidFocus)
            try c.encode(fractalAppearance, forKey: .fractalAppearance)
            try c.encode(overlayFractalFusion, forKey: .overlayFractalFusion)
            try c.encode(overlayRectMinX, forKey: .overlayRectMinX)
            try c.encode(overlayRectMinY, forKey: .overlayRectMinY)
            try c.encode(overlayRectWidth, forKey: .overlayRectWidth)
            try c.encode(overlayRectHeight, forKey: .overlayRectHeight)
        }
    }

    var layer: LayerControls = .init()
}
