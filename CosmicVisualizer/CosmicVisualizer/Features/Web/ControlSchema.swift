import Foundation

/// Describes control sections for web UI (`GET /api/schema`).
struct ControlSchema: Codable, Equatable, Sendable {
    struct Section: Codable, Equatable, Sendable {
        var id: String
        var title: String
        var fields: [Field]
    }

    struct Field: Codable, Equatable, Sendable {
        var id: String
        var label: String
        /// float | bool | int | string | command
        var kind: String
        var min: Double?
        var max: Double?
        var commandType: String?
    }

    var version: Int = 1
    var sections: [Section]

    static func cosmicDefault() -> ControlSchema {
        ControlSchema(sections: [
            Section(
                id: "transport",
                title: "Transport",
                fields: [
                    Field(id: "syncSource", label: "Tempo source", kind: "string", min: nil, max: nil, commandType: nil),
                    Field(id: "tapTempo", label: "Tap tempo", kind: "command", min: nil, max: nil, commandType: "TapTempo"),
                    Field(id: "manualBPM", label: "Manual BPM", kind: "float", min: 40, max: 220, commandType: "SetManualBPM"),
                ]
            ),
            Section(
                id: "scene",
                title: "Scene",
                fields: [
                    Field(id: "prev", label: "Previous scene", kind: "command", commandType: "PreviousScene"),
                    Field(id: "next", label: "Next scene", kind: "command", commandType: "NextScene"),
                    Field(id: "random", label: "Random scene", kind: "command", commandType: "RandomScene"),
                    Field(id: "liquid", label: "Liquid light", kind: "bool", commandType: "SetLiquidLightEnabled"),
                ]
            ),
            Section(
                id: "layer",
                title: "Layer (current scene)",
                fields: [
                    Field(id: "fractalZoom", label: "Fractal zoom", kind: "float", min: 0.08, max: 24, commandType: "SetFractalZoom"),
                    Field(id: "liquidTurbulence", label: "Liquid turbulence", kind: "float", min: 0.2, max: 2.5, commandType: "SetLiquidTurbulence"),
                    Field(id: "compositeBlend", label: "Composite blend", kind: "float", min: 0, max: 1, commandType: "SetCompositeBlend"),
                    Field(id: "liquidFocus", label: "Liquid focus (fuzzy → sharp blobs)", kind: "float", min: 0, max: 1, commandType: "SetLiquidFocus"),
                    Field(id: "fractalAppearance", label: "Fractal look (palette gradient → dark neon wire)", kind: "float", min: 0, max: 1, commandType: "SetFractalAppearance"),
                    Field(id: "overlayFractalFusion", label: "Logo ↔ fractal fusion", kind: "float", min: 0, max: 1, commandType: "SetOverlayFractalFusion"),
                    Field(id: "fractalExplore", label: "Fractal explore", kind: "float", min: 0, max: 1, commandType: "SetFractalExplore"),
                    Field(id: "fractalExploreSpeed", label: "Explore speed", kind: "float", min: 0.05, max: 6, commandType: "SetFractalExploreSpeed"),
                    Field(id: "fractalIterBoost", label: "Iteration boost", kind: "float", min: 0.25, max: 3, commandType: "SetFractalIterBoost"),
                    Field(id: "zoomEffectType", label: "Zoom motion (0 standard,1 infinite tunnel,2 event horizon)", kind: "float", min: 0, max: 2, commandType: "SetZoomEffectType"),
                    Field(id: "liquidReconstituteAmount", label: "Liquid reconstitute", kind: "float", min: 0, max: 1, commandType: "SetLiquidReconstituteAmount"),
                    Field(id: "liquidReconstituteRate", label: "Reconstitute rate", kind: "float", min: 0.05, max: 3, commandType: "SetLiquidReconstituteRate"),
                    Field(id: "dyeMix", label: "Dye mix", kind: "float", min: 0, max: 1, commandType: "SetDyeMix"),
                    Field(id: "fractalSmoothShading", label: "Smooth fractal shading", kind: "float", min: 0, max: 1, commandType: "SetFractalSmoothShading"),
                    Field(id: "compositeBloomStrength", label: "Bloom", kind: "float", min: 0, max: 0.5, commandType: "SetCompositeBloomStrength"),
                    Field(id: "compositeVignetteStrength", label: "Vignette", kind: "float", min: 0, max: 0.85, commandType: "SetCompositeVignetteStrength"),
                ]
            ),
            Section(
                id: "scene_edit",
                title: "Scene list",
                fields: [
                    Field(id: "duplicate", label: "Duplicate current scene", kind: "command", commandType: "DuplicateScene"),
                    Field(id: "delete", label: "Delete current scene", kind: "command", commandType: "DeleteScene"),
                    Field(id: "persist", label: "Save scenes to disk", kind: "command", commandType: "PersistScenes"),
                ]
            ),
            Section(
                id: "output",
                title: "Output",
                fields: [
                    Field(id: "openPresentation", label: "Open presentation display", kind: "command", commandType: "OpenExternalVisualization"),
                    Field(id: "closePresentation", label: "Close presentation", kind: "command", commandType: "CloseExternalVisualization"),
                ]
            ),
            Section(
                id: "rest",
                title: "REST (see docs)",
                fields: [
                    Field(id: "getScenes", label: "GET /api/scenes", kind: "string", commandType: nil),
                    Field(id: "putScenes", label: "PUT /api/scenes", kind: "string", commandType: nil),
                    Field(id: "postReorder", label: "POST /api/scenes/reorder", kind: "string", commandType: nil),
                    Field(id: "getSettings", label: "GET /api/settings", kind: "string", commandType: nil),
                    Field(id: "putSettings", label: "PUT /api/settings", kind: "string", commandType: nil),
                    Field(id: "midiMap", label: "GET/PUT /api/midi_mapping", kind: "string", commandType: nil),
                ]
            ),
        ])
    }
}
