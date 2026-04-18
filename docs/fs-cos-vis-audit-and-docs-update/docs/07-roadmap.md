# Roadmap
Updated: 2026-04-17

## Product state

FS-COS-VIS is a late-stage hybrid macOS application that combines:
- real-time cosmic visualization
- fractal + liquid-light scene authoring
- live show performance controls
- lighting patch/cue/modulation/stage workflows
- verification and transport scaffolding
- beta distribution support

## Completed foundation

- Audio input picker, channel selection, live analysis metrics, FFT/BPM feeds
- Fractal + liquid render stack with compositing and palette controls
- Extended fractal zoom motion modes with expanded modulation range
- Live Show, Scene Studio, Controller, Settings, and Lighting Workspace surfaces
- Scene persistence, overlays, transitions, and performance workflow refinements
- Quick palette access in Live Show for performance parity
- Live output recorder with source picker, quality presets, share/reveal flow, and health indicators
- External display routing
- MIDI mapping baseline
- HTTP/WebSocket remote control
- OSC UDP control surface with state query support
- DMX/lighting vertical slice:
  - fixture library and patching
  - cues and crossfades
  - bookmark metadata for overlays
  - modulation runtime
  - stage layout and 2.5D preview
  - fog/haze learn and safety controls
  - OFL fixture import and curated fallback coverage
  - fixture verification workflow
- Project package import/export UI
- First-run setup wizard
- Beta update checks and feedback/error-log reporting controls

## In progress

- Verification quality pass
  - stronger confidence scoring
  - deterministic fallback/test coverage
  - better correction/report workflows
  - low-light/overexposure guidance
- Stage plot UX polish
  - scan setup guidance
  - object-editing polish
  - advanced authoring ergonomics
- Network DMX expansion
  - Art-Net/sACN scaffolding
  - packet send path
  - diagnostics wiring
- Inbound DMX and RDM scaffolding
- Performance profiling for larger fixture counts / modulation density
- Release automation hardening
  - Sparkle publication
  - signing/notarization workflow proofing

## Next priority work

### P0 — Documentation and IA coherence
- Rewrite README to reflect current app, not “starter” positioning
- Align audit, roadmap, todo, and UI spec
- Document consolidation decisions:
  - Palette Browser → Scene Studio
  - Overlay Manager → Scene Studio

### P1 — Live UX clarity
- Add explicit input meter to Live Show
- Add stronger beat pulse/beat indicator
- Separate live-safe actions from authoring utility actions
- Improve active scene/palette/cue visibility

### P2 — Lighting workspace efficiency
- Split Lighting Workspace into clearer sub-modes:
  - Patch
  - Cues
  - Stage
  - Verify
  - Tools
- Move JSON transport utilities into a more clearly advanced area

### P3 — Verification and reliability
- Deterministic tests
- cancellation/resume hardening
- camera guidance improvements
- correction workflows

### P4 — Transport and parity
- finish Art-Net/sACN paths
- finish inbound DMX
- finish RDM workflow
- verify OSC/native parity

### P5 — Release readiness
- prove signed/notarized beta flow
- finalize Sparkle-compatible release process
- produce tester-ready DMG artifacts

## Release target

Beta-ready means:
- docs are coherent
- live use is clear and safe
- beta tester can install without Xcode
- transport scaffolds are honestly labeled
- recorder, update, and feedback workflows are usable