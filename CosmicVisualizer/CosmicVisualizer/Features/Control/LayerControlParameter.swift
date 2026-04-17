import Foundation

/// Stable IDs for layer sliders (matches `ControlSchema` layer fields and MIDI continuous maps).
enum LayerControlParameter: String, CaseIterable, Identifiable, Sendable {
    case fractalZoom
    case liquidTurbulence
    case compositeBlend
    case liquidFocus
    case fractalAppearance
    case overlayFractalFusion

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fractalZoom: "Fractal zoom"
        case .liquidTurbulence: "Liquid turbulence"
        case .compositeBlend: "Composite blend"
        case .liquidFocus: "Liquid focus"
        case .fractalAppearance: "Fractal look"
        case .overlayFractalFusion: "Logo ↔ fractal fusion"
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
