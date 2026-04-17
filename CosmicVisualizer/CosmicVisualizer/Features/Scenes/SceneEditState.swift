import Foundation
import simd

/// Authoring controls for a single scene (persisted separately from `VisualizationScene` identity).
struct SceneEditState: Codable, Equatable, Hashable {
    struct LayerControls: Codable, Equatable, Hashable {
        struct LiquidDropperLayer: Codable, Equatable, Hashable, Identifiable {
            var id: UUID = UUID()
            var name: String
            var colorR: Float
            var colorG: Float
            var colorB: Float
            /// Higher = thicker pour (smaller, stronger splats).
            var viscosity: Float

            init(
                id: UUID = UUID(),
                name: String,
                colorR: Float,
                colorG: Float,
                colorB: Float,
                viscosity: Float
            ) {
                self.id = id
                self.name = name
                self.colorR = colorR
                self.colorG = colorG
                self.colorB = colorB
                self.viscosity = viscosity
            }
        }

        static let maxDropperLayers = 8
        static let defaultDropperLayers: [LiquidDropperLayer] = [
            LiquidDropperLayer(name: "Base", colorR: 0.2, colorG: 0.85, colorB: 1.0, viscosity: 0.85),
            LiquidDropperLayer(name: "Layer 1", colorR: 1.0, colorG: 0.45, colorB: 0.9, viscosity: 0.62),
            LiquidDropperLayer(name: "Layer 2", colorR: 1.0, colorG: 0.75, colorB: 0.25, viscosity: 0.4),
        ]

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

        /// 0 = Julia, 1 = Mandelbrot, 2 = Burning Ship, 3 = Tricorn.
        var fractalGeometryIndex: Float = 0
        /// Animated fractal exploration (0 = off, 1 = full).
        var fractalExplore: Float = 0
        var fractalExploreSpeed: Float = 0.35
        var fractalPanX: Float = 0
        var fractalPanY: Float = 0
        /// Multiplier on iteration budget (GPU clamps).
        var fractalIterBoost: Float = 1
        /// 0 = drift, 1 = pulse, 2 = breathe.
        var zoomEffectType: Float = 0
        /// Tray tilt for liquid phase (normalized -1…1).
        var liquidTiltX: Float = 0
        var liquidTiltY: Float = 0
        /// 0 = dissolve quickly, 1 = persist until cleared.
        var liquidDissolveHold: Float = 0.65
        /// 0 = disabled, 1 = fully reconstituting bubbly motion.
        var liquidReconstituteAmount: Float = 0
        /// Oscillation rate when BPM sync is off.
        var liquidReconstituteRate: Float = 0.55
        /// When enabled, reconstitute oscillation follows BPM.
        var liquidReconstituteBPMSync: Bool = false
        var liquidDropperLayers: [LiquidDropperLayer] = LayerControls.defaultDropperLayers
        var activeDropperLayerIndex: Int = 0

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
            case fractalGeometryIndex
            case fractalExplore
            case fractalExploreSpeed
            case fractalPanX
            case fractalPanY
            case fractalIterBoost
            case zoomEffectType
            case liquidTiltX
            case liquidTiltY
            case liquidDissolveHold
            case liquidReconstituteAmount
            case liquidReconstituteRate
            case liquidReconstituteBPMSync
            case liquidDropperLayers
            case activeDropperLayerIndex
            // v1 legacy keys
            case dropperColorR
            case dropperColorG
            case dropperColorB
            case dropperViscosity
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
            overlayRectHeight: Float = 1,
            fractalGeometryIndex: Float = 0,
            fractalExplore: Float = 0,
            fractalExploreSpeed: Float = 0.35,
            fractalPanX: Float = 0,
            fractalPanY: Float = 0,
            fractalIterBoost: Float = 1,
            zoomEffectType: Float = 0,
            liquidTiltX: Float = 0,
            liquidTiltY: Float = 0,
            liquidDissolveHold: Float = 0.65,
            liquidReconstituteAmount: Float = 0,
            liquidReconstituteRate: Float = 0.55,
            liquidReconstituteBPMSync: Bool = false,
            liquidDropperLayers: [LiquidDropperLayer] = LayerControls.defaultDropperLayers,
            activeDropperLayerIndex: Int = 0
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
            self.fractalGeometryIndex = fractalGeometryIndex
            self.fractalExplore = fractalExplore
            self.fractalExploreSpeed = fractalExploreSpeed
            self.fractalPanX = fractalPanX
            self.fractalPanY = fractalPanY
            self.fractalIterBoost = fractalIterBoost
            self.zoomEffectType = zoomEffectType
            self.liquidTiltX = liquidTiltX
            self.liquidTiltY = liquidTiltY
            self.liquidDissolveHold = liquidDissolveHold
            self.liquidReconstituteAmount = liquidReconstituteAmount
            self.liquidReconstituteRate = liquidReconstituteRate
            self.liquidReconstituteBPMSync = liquidReconstituteBPMSync
            self.liquidDropperLayers = Array(liquidDropperLayers.prefix(Self.maxDropperLayers))
            self.activeDropperLayerIndex = max(0, min(self.liquidDropperLayers.count - 1, activeDropperLayerIndex))
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
            fractalGeometryIndex = try c.decodeIfPresent(Float.self, forKey: .fractalGeometryIndex) ?? 0
            fractalExplore = try c.decodeIfPresent(Float.self, forKey: .fractalExplore) ?? 0
            fractalExploreSpeed = try c.decodeIfPresent(Float.self, forKey: .fractalExploreSpeed) ?? 0.35
            fractalPanX = try c.decodeIfPresent(Float.self, forKey: .fractalPanX) ?? 0
            fractalPanY = try c.decodeIfPresent(Float.self, forKey: .fractalPanY) ?? 0
            fractalIterBoost = try c.decodeIfPresent(Float.self, forKey: .fractalIterBoost) ?? 1
            zoomEffectType = try c.decodeIfPresent(Float.self, forKey: .zoomEffectType) ?? 0
            liquidTiltX = try c.decodeIfPresent(Float.self, forKey: .liquidTiltX) ?? 0
            liquidTiltY = try c.decodeIfPresent(Float.self, forKey: .liquidTiltY) ?? 0
            liquidDissolveHold = try c.decodeIfPresent(Float.self, forKey: .liquidDissolveHold) ?? 0.65
            liquidReconstituteAmount = try c.decodeIfPresent(Float.self, forKey: .liquidReconstituteAmount) ?? 0
            liquidReconstituteRate = try c.decodeIfPresent(Float.self, forKey: .liquidReconstituteRate) ?? 0.55
            liquidReconstituteBPMSync = try c.decodeIfPresent(Bool.self, forKey: .liquidReconstituteBPMSync) ?? false
            let decodedLayers = try c.decodeIfPresent([LiquidDropperLayer].self, forKey: .liquidDropperLayers) ?? []
            if decodedLayers.isEmpty {
                let legacyR = try c.decodeIfPresent(Float.self, forKey: .dropperColorR) ?? 0.2
                let legacyG = try c.decodeIfPresent(Float.self, forKey: .dropperColorG) ?? 0.85
                let legacyB = try c.decodeIfPresent(Float.self, forKey: .dropperColorB) ?? 1
                let legacyVisc = try c.decodeIfPresent(Float.self, forKey: .dropperViscosity) ?? 0.5
                liquidDropperLayers = [
                    LiquidDropperLayer(
                        name: "Base",
                        colorR: legacyR,
                        colorG: legacyG,
                        colorB: legacyB,
                        viscosity: legacyVisc
                    ),
                    LayerControls.defaultDropperLayers[1],
                    LayerControls.defaultDropperLayers[2],
                ]
            } else {
                liquidDropperLayers = Array(decodedLayers.prefix(Self.maxDropperLayers))
            }
            if liquidDropperLayers.isEmpty {
                liquidDropperLayers = Self.defaultDropperLayers
            }
            let storedActive = try c.decodeIfPresent(Int.self, forKey: .activeDropperLayerIndex) ?? 0
            activeDropperLayerIndex = max(0, min(liquidDropperLayers.count - 1, storedActive))
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
            try c.encode(fractalGeometryIndex, forKey: .fractalGeometryIndex)
            try c.encode(fractalExplore, forKey: .fractalExplore)
            try c.encode(fractalExploreSpeed, forKey: .fractalExploreSpeed)
            try c.encode(fractalPanX, forKey: .fractalPanX)
            try c.encode(fractalPanY, forKey: .fractalPanY)
            try c.encode(fractalIterBoost, forKey: .fractalIterBoost)
            try c.encode(zoomEffectType, forKey: .zoomEffectType)
            try c.encode(liquidTiltX, forKey: .liquidTiltX)
            try c.encode(liquidTiltY, forKey: .liquidTiltY)
            try c.encode(liquidDissolveHold, forKey: .liquidDissolveHold)
            try c.encode(liquidReconstituteAmount, forKey: .liquidReconstituteAmount)
            try c.encode(liquidReconstituteRate, forKey: .liquidReconstituteRate)
            try c.encode(liquidReconstituteBPMSync, forKey: .liquidReconstituteBPMSync)
            try c.encode(liquidDropperLayers, forKey: .liquidDropperLayers)
            try c.encode(activeDropperLayerIndex, forKey: .activeDropperLayerIndex)
        }
    }

    var layer: LayerControls = .init()
}
