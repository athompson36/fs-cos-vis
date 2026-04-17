import Foundation

/// Stable IDs for layer sliders (matches `ControlSchema` layer fields and MIDI continuous maps).
enum LayerControlParameter: String, CaseIterable, Identifiable, Sendable {
    case fractalZoom
    case liquidTurbulence
    case compositeBlend
    case liquidFocus
    case fractalAppearance
    case overlayFractalFusion
    case fractalExplore
    case fractalExploreSpeed
    case fractalIterBoost
    case zoomEffectType
    case liquidReconstituteAmount
    case liquidReconstituteRate
    case liquidReconstituteBPMSync
    case dyeMix
    case fractalSmoothShading
    case compositeBloomStrength
    case compositeVignetteStrength

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fractalZoom: "Fractal zoom"
        case .liquidTurbulence: "Liquid turbulence"
        case .compositeBlend: "Composite blend"
        case .liquidFocus: "Liquid focus"
        case .fractalAppearance: "Fractal look"
        case .overlayFractalFusion: "Logo ↔ fractal fusion"
        case .fractalExplore: "Fractal explore"
        case .fractalExploreSpeed: "Explore speed"
        case .fractalIterBoost: "Iteration boost"
        case .zoomEffectType: "Zoom motion"
        case .liquidReconstituteAmount: "Liquid reconstitute"
        case .liquidReconstituteRate: "Reconstitute rate"
        case .liquidReconstituteBPMSync: "Reconstitute BPM sync"
        case .dyeMix: "Dye mix"
        case .fractalSmoothShading: "Smooth shading"
        case .compositeBloomStrength: "Bloom"
        case .compositeVignetteStrength: "Vignette"
        }
    }

    /// Slider range used for UI and MIDI 0…127 lerp.
    var floatRange: ClosedRange<Float> {
        switch self {
        case .fractalZoom: 0.12 ... 4.5
        case .liquidTurbulence: 0.2 ... 2.5
        case .compositeBlend: 0 ... 1
        case .liquidFocus: 0 ... 1
        case .fractalAppearance: 0 ... 1
        case .overlayFractalFusion: 0 ... 1
        case .fractalExplore: 0 ... 1
        case .fractalExploreSpeed: 0.05 ... 1.2
        case .fractalIterBoost: 0.25 ... 3
        case .zoomEffectType: 0 ... 2
        case .liquidReconstituteAmount: 0 ... 1
        case .liquidReconstituteRate: 0.05 ... 3
        case .liquidReconstituteBPMSync: 0 ... 1
        case .dyeMix: 0 ... 1
        case .fractalSmoothShading: 0 ... 1
        case .compositeBloomStrength: 0 ... 0.5
        case .compositeVignetteStrength: 0 ... 0.85
        }
    }

    func value(fromMidi7 v: Int) -> Float {
        let t = Float(max(0, min(127, v))) / 127.0
        let lo = floatRange.lowerBound
        let hi = floatRange.upperBound
        return lo + t * (hi - lo)
    }

    func remoteCommand(with value: Float) -> RemoteControlCommand {
        switch self {
        case .fractalZoom:
            RemoteControlCommand(type: "SetFractalZoom", fractalZoom: value)
        case .liquidTurbulence:
            RemoteControlCommand(type: "SetLiquidTurbulence", liquidTurbulence: value)
        case .compositeBlend:
            RemoteControlCommand(type: "SetCompositeBlend", compositeBlend: value)
        case .liquidFocus:
            RemoteControlCommand(type: "SetLiquidFocus", liquidFocus: value)
        case .fractalAppearance:
            RemoteControlCommand(type: "SetFractalAppearance", fractalAppearance: value)
        case .overlayFractalFusion:
            RemoteControlCommand(type: "SetOverlayFractalFusion", overlayFractalFusion: value)
        case .fractalExplore:
            RemoteControlCommand(type: "SetFractalExplore", fractalExplore: value)
        case .fractalExploreSpeed:
            RemoteControlCommand(type: "SetFractalExploreSpeed", fractalExploreSpeed: value)
        case .fractalIterBoost:
            RemoteControlCommand(type: "SetFractalIterBoost", fractalIterBoost: value)
        case .zoomEffectType:
            RemoteControlCommand(type: "SetZoomEffectType", index: Int(round(value)))
        case .liquidReconstituteAmount:
            RemoteControlCommand(type: "SetLiquidReconstituteAmount", liquidReconstituteAmount: value)
        case .liquidReconstituteRate:
            RemoteControlCommand(type: "SetLiquidReconstituteRate", liquidReconstituteRate: value)
        case .liquidReconstituteBPMSync:
            RemoteControlCommand(type: "SetLiquidReconstituteBPMSync", enabled: value >= 0.5)
        case .dyeMix:
            RemoteControlCommand(type: "SetDyeMix", dyeMix: value)
        case .fractalSmoothShading:
            RemoteControlCommand(type: "SetFractalSmoothShading", fractalSmoothShading: value)
        case .compositeBloomStrength:
            RemoteControlCommand(type: "SetCompositeBloomStrength", compositeBloomStrength: value)
        case .compositeVignetteStrength:
            RemoteControlCommand(type: "SetCompositeVignetteStrength", compositeVignetteStrength: value)
        }
    }

    init?(parameterID: String) {
        self.init(rawValue: parameterID)
    }
}

/// How the Controller arms “learn next hardware event” for mapping. DMX paths are reserved until incoming DMX exists.
enum ControlLearnMode: String, CaseIterable, Identifiable, Sendable {
    case off
    case midi
    case dmx
    case both

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: "Off"
        case .midi: "MIDI"
        case .dmx: "DMX"
        case .both: "MIDI + DMX"
        }
    }

    /// When true, the next MIDI CC assigns the selected layer parameter.
    var allowsMidiLearn: Bool {
        self == .midi || self == .both
    }

    /// Reserved for Art-Net / sACN input.
    var allowsDMXLearn: Bool {
        self == .dmx || self == .both
    }

    var isSelectableInUI: Bool {
        self == .off || self == .midi
    }
}
