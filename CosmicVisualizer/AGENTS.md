# Agent notes (Cosmic Visualizer)

## Performance vs authoring

- **Live Show** and **Performance** mode prioritize a large preview and minimal chrome. Prefer toggles and cue strips over dense inspectors.
- **Scene Studio**, **Lighting workspace**, and **Settings** are authoring surfaces: `GroupBox`, forms, tabs, and inspectors are appropriate.

## Key modules

- **Show project:** `Features/Project/ProjectStack.swift` — folder package (`project.json` + JSON payloads + `Media/` + `context/`).
- **AI context:** `Features/AI/AIStack.swift` — `machine.json`, `dmx_universe.md`, `AIToolRegistry`, optional `LLMChatClient`, Keychain API key.
- **Live cues:** `App/LiveShowCueStripsView.swift` — lighting/backdrop strips; bookmarks live in cue documents.
- **OFL:** `Features/Lighting/OFLFixtureImportService.swift` — fetch/cache fixtures, map to `FixtureProfile` with capability strings.
- **Calibration:** `WebcamCaptureService` + `DMXSweepCalibrationService` — writes `context/calibration.json`; not for audience-facing use without shielding.

## Tool names (hybrid AI)

Local tools: `refresh_context`, `set_active_lighting_cue_index`, `set_active_backdrop_cue_index`, `apply_dmx_patch_document`, `append_lighting_cues_json`, `export_fixture_ofl_stub`. LLM replies must be JSON: `{"tool_calls":[...]}` only.
