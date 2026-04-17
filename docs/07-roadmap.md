# Roadmap

## Status snapshot (2026-04-17)

This roadmap now tracks implementation status, not just concept phases.

## Completed foundation

- Audio input picker, live analysis metrics, FFT/BPM feeds
- Fractal + liquid render stack with compositing and palette controls
  - Extended fractal zoom motion modes (Standard / Infinite Tunnel / Event Horizon) with higher modulation range
- Live and studio control surfaces with external display routing
  - Live output recorder with source picker, project-folder recording destination, and share/reveal flow
  - First-run setup wizard with skippable steps (project/audio/output/DMX/AI)
  - Beta update and operator feedback/reporting controls in Settings
- Scene persistence, overlays, transitions, and performance workflow refinements
- MIDI mapping baseline and remote/web control API foundation
- DMX/lighting vertical slice:
  - fixture library and patching
  - cues and crossfades
  - cue bookmark metadata for dynamic song/artist overlay values
  - modulation runtime
  - stage layout + 2.5D preview
  - fog/haze learn and safety controls
  - OFL fixture import and enriched catalog pipeline (OFL sync + bundled curated fallback source)
  - fixture verification (assisted camera workflow)
  - overlay element timeout auto-hide and metadata-bound text rendering

## In progress

- Fixture verification quality pass:
  - stronger confidence scoring
  - richer dual-camera guidance and validation feedback
  - deterministic dual-camera fallback and stage-camera persistence test coverage
  - overlay metadata/timeout cue-transition regression coverage
- Stage plot UX:
  - camera overlay guidance, object editing polish, scan-setup flow
  - implemented: snap-to-grid, duplicate object, lock object, and layer ordering controls
 - Authoring surface consolidation:
   - Palette Browser and Overlay Manager remain intentionally consolidated into Scene Studio
   - Live Show now includes quick palette access (picker + prev/next) for performance parity

## Next up (backlog)

- Network DMX expansion (Art-Net/sACN multi-universe)
  - started: DMX output mode scaffolding and operator settings wiring for Art-Net/sACN target + universe selection
  - implemented: initial UDP transport send path and packet-construction test coverage
- Inbound DMX and RDM discovery path
  - started: inbound Art-Net/sACN listener scaffold with universe filtering and HTP/LPT merge diagnostics
  - started: RDM discovery/probe scaffold with mock transport-safe discovery results and operator diagnostics
- Performance profiling for larger fixture counts / modulation density
  - started: DMX tick profiler with runtime timing diagnostics and over-budget frame tracking in Settings
- OSC control surface parity with existing web/MIDI paths
  - started: OSC UDP control listener with token-gated command parsing for scene/tempo/parameter commands
  - expanded: OSC parity mappings for cue index, UUID scene jumps/palette select, and additional performance toggles
  - added: OSC state query responder (`/cosmic/state/get`) using the same app snapshot contract as web state
  - expanded: live output recorder parity (`start`/`stop`, source, quality) with recorder status/latest output path in web state snapshot
- Capture/export pipeline hardening and automation (codec tuning, permissions diagnostics, long-duration stability)
  - implemented recorder quality presets (24/30/60 fps, bitrate tuning) and live audio-source diagnostics in Live Show
  - implemented recorder health indicators for source availability and screen/microphone permission states
  - implemented setup wizard step analytics and exportable onboarding diagnostics JSON
  - implemented show package archive import/export automation (`.cosmicshow.zip`) plus CI smoke validation workflow
- Sparkle appcast publication and signed installer automation hardening
- Cross-platform feasibility spikes (Windows path)

## Notes

- DMX stack remains intentionally USB/OpenDMX + simulation first while transport abstractions mature.
- Full “console parity” workflows are deferred until multi-universe/network transport is production-stable.

