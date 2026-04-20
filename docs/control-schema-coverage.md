# `ControlSchema` vs `applyRemoteCommandOnMainThread` (Gate 2.1)

**Sources:** [`ControlSchema.swift`](../FSDMXVision/FSDMXVision/Features/Web/ControlSchema.swift) (`cosmicDefault()`), [`AppModel.applyRemoteCommandOnMainThread`](../FSDMXVision/FSDMXVision/App/AppModel.swift).

**Rule:** `GET /api/schema` lists a **subset** of buttons/sliders for the bundled web UI. **`POST /api/command`** accepts **any** `RemoteControlCommand` string in `type` that the app implements—same as [`control-parity.md`](control-parity.md).

## Command types listed in `ControlSchema.cosmicDefault()` (`commandType` non-nil)

These appear in the bundled schema JSON:

`TapTempo`, `SetManualBPM`, `PreviousScene`, `NextScene`, `RandomScene`, `SetLiquidLightEnabled`, `SetFractalZoom`, `SetLiquidTurbulence`, `SetCompositeBlend`, `SetLiquidFocus`, `SetFractalAppearance`, `SetOverlayFractalFusion`, `SetFractalExplore`, `SetFractalExploreSpeed`, `SetFractalIterBoost`, `SetZoomEffectType`, `SetLiquidReconstituteAmount`, `SetLiquidReconstituteRate`, `SetDyeMix`, `SetFractalSmoothShading`, `SetCompositeBloomStrength`, `SetCompositeVignetteStrength`, `SetSpectrumWarpAmount`, `SetFractalGeometryIndex`, `DuplicateScene`, `DeleteScene`, `PersistScenes`, `OpenExternalVisualization`, `CloseExternalVisualization`, `StartLiveOutputRecording`, `StopLiveOutputRecording`, `SetLiveOutputRecordingSource`, `SetLiveOutputRecordingQualityPreset`

**JSON shapes:** `SetSpectrumWarpAmount` uses `{ "type": "SetSpectrumWarpAmount", "spectrumWarpAmount": 0.35 }`. `SetFractalGeometryIndex` uses `{ "type": "SetFractalGeometryIndex", "index": 5 }` (int **0…6**).

**Note:** `SetLiquidReconstituteBPMSync` is implemented in `applyRemoteCommandOnMainThread` but **not** exposed in `ControlSchema` (add a field if the web UI should toggle it).

## Implemented in `applyRemoteCommandOnMainThread` but not in `ControlSchema`

Use **raw** `POST /api/command` JSON (or OSC where supported—see [`osc-control.md`](osc-control.md)):

| Command type | Typical use |
|--------------|-------------|
| `SetTempoSource` | Tempo sync source |
| `CueSceneIndex`, `JumpToSceneIndex` | Scene by index |
| `CueScene`, `JumpToScene` | Scene by UUID |
| `SetLiquidReconstituteBPMSync` | Layer toggle |
| `PersistSceneControls` | Save scene controls |
| `SetPerformanceMode` | Performance vs authoring |
| `SetOverlayEnabled` | Global overlay |
| `ReorderScenes` | Also `POST /api/scenes/reorder` |
| `SetRemoteControlEnabled`, `SetRemotePort`, `SetBindLAN`, `SetAuthToken` | Remote HTTP |
| `SetMIDIPortUID`, `SetDMXSerialPath`, `SetDMXEnabled` | Settings |
| `SetExternalScreenIndex` | External display index |
| `SetSelectedPalette` | Palette UUID |
| `SetAudioInputIndex` | Audio device index |
| `ToggleMainWindowFullscreen` | Window chrome |
| `RefreshAudioDevices` | Rescan devices |
| `SetActiveLightingCueIndex`, `NextLightingCue`, `PreviousLightingCue` | Lighting |

**REST surfaces** (not `commandType` in schema; documented in schema “REST” section): `GET/PUT /api/scenes`, `POST /api/scenes/reorder`, `GET/PUT /api/settings`, `GET/PUT /api/midi_mapping`.

## Parity exit (Gate 2)

- Schema gap is **intentional** for a compact web UI; full surface = raw `POST /api/command`.
- Expand `ControlSchema` only when operators need specific types in the **bundled** HTML UI without raw JSON.

**Last updated:** 2026-04-20
