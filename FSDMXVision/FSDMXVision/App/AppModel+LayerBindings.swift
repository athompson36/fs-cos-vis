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
                case .fractalExplore:
                    return layer?.fractalExplore ?? defaults.fractalExplore
                case .fractalExploreSpeed:
                    return layer?.fractalExploreSpeed ?? defaults.fractalExploreSpeed
                case .fractalIterBoost:
                    return layer?.fractalIterBoost ?? defaults.fractalIterBoost
                case .zoomEffectType:
                    return layer?.zoomEffectType ?? defaults.zoomEffectType
                case .liquidReconstituteAmount:
                    return layer?.liquidReconstituteAmount ?? defaults.liquidReconstituteAmount
                case .liquidReconstituteRate:
                    return layer?.liquidReconstituteRate ?? defaults.liquidReconstituteRate
                case .liquidReconstituteBPMSync:
                    return (layer?.liquidReconstituteBPMSync ?? defaults.liquidReconstituteBPMSync) ? 1 : 0
                case .dyeMix:
                    return layer?.dyeMix ?? defaults.dyeMix
                case .fractalSmoothShading:
                    return layer?.fractalSmoothShading ?? defaults.fractalSmoothShading
                case .compositeBloomStrength:
                    return layer?.compositeBloomStrength ?? defaults.compositeBloomStrength
                case .compositeVignetteStrength:
                    return layer?.compositeVignetteStrength ?? defaults.compositeVignetteStrength
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
        case .fractalExplore: defaults.fractalExplore
        case .fractalExploreSpeed: defaults.fractalExploreSpeed
        case .fractalIterBoost: defaults.fractalIterBoost
        case .zoomEffectType: defaults.zoomEffectType
        case .liquidReconstituteAmount: defaults.liquidReconstituteAmount
        case .liquidReconstituteRate: defaults.liquidReconstituteRate
        case .liquidReconstituteBPMSync: defaults.liquidReconstituteBPMSync ? 1 : 0
        case .dyeMix: defaults.dyeMix
        case .fractalSmoothShading: defaults.fractalSmoothShading
        case .compositeBloomStrength: defaults.compositeBloomStrength
        case .compositeVignetteStrength: defaults.compositeVignetteStrength
        }
    }
}
