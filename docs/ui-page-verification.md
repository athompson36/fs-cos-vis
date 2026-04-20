# UI page verification — docs vs code

**Purpose:** Trace [`03-ui-ux-spec.md`](03-ui-ux-spec.md), [`feature-surface-matrix.md`](feature-surface-matrix.md), and [`project-audit-and-feature-status.md`](project-audit-and-feature-status.md) against SwiftUI entry points. **Status:** ✓ = present in code; ⚠ = doc wording drift or backlog nuance; — = N/A by design.

**Last verified:** 2026-04-20 (against current `main`).

---

## Live Show (`LiveShowView.swift`)

| Spec / audit expectation | Code evidence | Status |
|--------------------------|---------------|--------|
| Audio device + channel mode | `devicePicker` | ✓ |
| RMS/peak meter + beat-phase ring + BPM/confidence | `audioLevelAndBeatPulseRow` | ✓ |
| Active summary (scene, palette, lighting cue) | `liveContextSummaryStrip` | ✓ |
| Scene prev/next/random, fullscreen, tap tempo | `performanceSceneActionsRow` (incl. `toggleMainWindowFullscreen`) | ✓ |
| Grouped Performance / Look / Capture | `performanceSceneActionsRow`, `quickPaletteControls`, `recordingControls` | ✓ |
| Quick palette, liquid toggle, overlay toggles | `quickPaletteControls`, `overlayAndLiquidToggles` | ✓ |
| Haze emergency | `fogHazeEmergencyRow` | ✓ |
| Recorder source/quality/share | `recordingControls` | ✓ |
| Performance mode; lighting/backdrop cue panel under preview | `performanceMode`, `SceneCueStripView` (non-Performance only), `LiveShowCueStripsView` (panel whenever Metal preview is up; row visibility via `lightingPerformanceStripEnabled` / `backdropPerformanceStripEnabled`, default **on**) | ✓ |
| Overlay tools in menu (not primary row) | `performanceSceneActionsRow` overlay `Menu` | ✓ |
| Remote parity (HTTP/OSC/state) | Not this file — `WebControlServer`, `ControlBus`; matrix row “Live Show performance UX” | ✓ (see control parity docs) |

---

## Scene Studio (`SceneStudioView.swift`)

| Spec / audit expectation | Code evidence | Status |
|--------------------------|---------------|--------|
| No standalone Palette/Overlay apps — consolidated here | IA in spec; authoring in this file | ✓ |
| Authoring sub-modes Scene·Look·Fractal·Liquid·Overlay·Palette | `SceneStudioAuthoringSection` + `authoringSectionPicker` / chips | ✓ |
| Preview vs controls split | `GeometryReader` wide/narrow layouts, `studioLivePreviewColumn` + `sceneStudioAuthoringColumn` | ✓ |
| Fractal / liquid / overlay / palette flows | `authoringSectionContent` switch | ✓ |
| Spectrum warp, fractal geometry 0…6 (Julia … orbit trap) | Fractal section: `spectrumWarpAmountBinding`, `fractalGeometryBinding` | ✓ (also `SetSpectrumWarpAmount` / `SetFractalGeometryIndex` via HTTP·OSC — see `control-schema-coverage.md`) |

---

## Controller (`ControllerView.swift`)

| Spec / audit expectation | Code evidence | Status |
|--------------------------|---------------|--------|
| Tempo, MIDI learn, mappings | Overview scroll: `tempoBlock`, `mappingLearnSection`, `mappingSummarySection` | ✓ |
| OSC summary / examples | `mappingSummarySection` | ✓ |
| Faders tab with fixture search | `ControllerMainSection.faders`, `faderSearchText`, `filteredDmxControlGroups` | ✓ |
| Planned badges on unavailable learn | `Text("Planned")`, `learnModeButtonDisabled(.dmx, …)` | ✓ |
| Scene vs DMX fader separation | `sceneFadersRegion` vs `dmxFadersRegion` / group styling in file | ✓ |

---

## Settings (`SettingsView.swift`)

| Spec / audit expectation | Code evidence | Status |
|--------------------------|---------------|--------|
| Basic / Advanced DMX transport tier | `SettingsTransportUITier`, `@AppStorage("settings.transportUITier")`, conditional sections | ✓ |
| Updates, feedback, show package | `updatesSection`, `feedbackSection`, `showProjectSection` | ✓ |
| Remote HTTP/WS, OSC, audio, MIDI, DMX | `remoteControlSection`, nested DMX/audio/MIDI blocks | ✓ |
| Diagnostics (output, inbound, frame timing, RDM) | Advanced-tier blocks + `dmxSection` / diagnostics groups | ✓ |
| Sparkle / beta / wizard | `updatesSection`, `betaSection`, wizard via `AppModel` from Root | ✓ |

---

## Lighting workspace (`LightingWorkspaceView.swift`)

| Spec / audit expectation | Code evidence | Status |
|--------------------------|---------------|--------|
| Patch (OFL + patch + rig) | `oflImportSection`, `patchSection`, `patchSearchText` filter | ✓ |
| Cues (lighting + backdrop) | `cueSection`, `backdropCueSection`, `cueSearchText` | ✓ |
| Stage (plan + 2.5D preview) | `stageWorkspaceScroll` → `StagePlanView`, `LightingPreview25DView` | ✓ |
| Verify (assisted verification, exposure banner) | `verificationWorkspaceTab`, `verificationExposureBanner`, `fixtureVerificationSection` | ✓ |
| Tools (modulation, JSON, copilot) | `toolsWorkspaceScroll` | ✓ |
| Five areas — **chip navigation** (not nested `TabView`) | `LightingWorkspaceSection`, `lightingWorkspaceSectionBar`, `@AppStorage("lighting.workspace.section")` | ✓ (spec text updated to “sections / chips”) |

**Doc note:** [`03-ui-ux-spec.md`](03-ui-ux-spec.md) previously said “Five tabs”; implementation uses the same five **logical areas** with a horizontal chip row (aligned with Scene Studio). ⚠ → resolved in spec.

---

## Bundled web UI (`Resources/WebControl/`)

| Spec / audit expectation | Code evidence | Status |
|--------------------------|---------------|--------|
| Single-page Cosmic Control | `index.html` + `app.js`; served by `WebControlServer` `GET *` | ✓ |
| Layer sliders incl. spectrum warp + fractal geometry | `spectrumWarp`, `fractalGeometry` inputs → `SetSpectrumWarpAmount`, `SetFractalGeometryIndex` | ✓ |
| Footer lists main REST/WS (`/health`, `/api/schema`, `/api/dmx/sim`, …) | `index.html` hint | ✓ |

---

## Cross-cutting (not a single page)

| Area | Where verified | Status |
|------|----------------|--------|
| `RemoteControlCommand` / HTTP / OSC / MIDI | `AppModel`, `WebControlServer`, `ControlBus` | ✓ — see [`control-parity.md`](control-parity.md) |
| Show package / `.cosmicshow.zip` | `SettingsView` + `ProjectStack` / tests | ✓ |
| Network DMX honest boundaries | Settings copy + `DMXOutputService`, `lighting-roadmap` | ✓ — lab/field in [`production-readiness-checklist.md`](production-readiness-checklist.md) Gate 3 |
| RDM mock vs real | UI + `RDMDiscoveryService`; backlog | ⚠ mock shipped; real RDM TBD (documented) |

---

## Gaps (by design or backlog)

These are **not** missing UI pages; they are **explicit** open items elsewhere:

- **Signed/notarized release, DMX field receivers, feedback relay deploy** — [`production-readiness-checklist.md`](production-readiness-checklist.md), [`distribution-checklist.md`](distribution-checklist.md).
- **Deeper fixture verification CV** — optional scope in [`project-audit-and-feature-status.md`](project-audit-and-feature-status.md) “Remaining gaps”.
- **Sidebar navigation** — spec lists as future spike only; current `TabView` IA is complete.

---

## How to re-run this check

1. Diff [`03-ui-ux-spec.md`](03-ui-ux-spec.md) “Implemented” bullets vs files above.  
2. Run tests: `xcodebuild test -scheme FSDMXVision -destination 'platform=macOS'`.  
3. Manual smoke: [`uat-checklist.md`](uat-checklist.md).
