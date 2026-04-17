import SwiftUI

extension AppModel {
    func layerFloatBinding(for parameter: LayerControlParameter) -> Binding<Float> {
        let defaults = SceneEditState.LayerControls()
        return Binding(
            get: {
                guard let id = self.selectedSceneID else {
                    return Self.defaultLayerValue(parameter, defaults: defaults)
                }
                let layer = self.sceneEditStates[id]?.layer
                switch parameter {
                case .fractalZoom:
                    return layer?.fractalZoom ?? defaults.fractalZoom
                case .liquidTurbulence:
                    return layer?.liquidTurbulence ?? defaults.liquidTurbulence
                case .compositeBlend:
                    return layer?.compositeBlend ?? defaults.compositeBlend
                case .liquidFocus:
                    return layer?.liquidFocus ?? defaults.liquidFocus
                case .fractalAppearance:
                    return layer?.fractalAppearance ?? defaults.fractalAppearance
                case .overlayFractalFusion:
                    return layer?.overlayFractalFusion ?? defaults.overlayFractalFusion
                }
            },
            set: { self.applyRemoteCommand(parameter.remoteCommand(with: $0)) }
        )
    }

    private static func defaultLayerValue(_ parameter: LayerControlParameter, defaults: SceneEditState.LayerControls) -> Float {
        switch parameter {
        case .fractalZoom: defaults.fractalZoom
        case .liquidTurbulence: defaults.liquidTurbulence
        case .compositeBlend: defaults.compositeBlend
        case .liquidFocus: defaults.liquidFocus
        case .fractalAppearance: defaults.fractalAppearance
        case .overlayFractalFusion: defaults.overlayFractalFusion
        }
    }
}
