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
  - OFL fixture import and curated catalog
  - fixture verification (assisted camera workflow)
  - overlay element timeout auto-hide and metadata-bound text rendering

## In progress

- Fixture verification quality pass:
  - stronger confidence scoring
  - richer dual-camera guidance and validation feedback
- Stage plot UX:
  - camera overlay guidance, object editing polish, scan-setup flow

## Next up (backlog)

- Network DMX expansion (Art-Net/sACN multi-universe)
- Inbound DMX and RDM discovery path
- OSC control surface parity with existing web/MIDI paths
- Capture/export pipeline hardening and automation (codec tuning, permissions diagnostics, long-duration stability)
- Sparkle appcast publication and signed installer automation hardening
- Cross-platform feasibility spikes (Windows path)

## Notes

- DMX stack remains intentionally USB/OpenDMX + simulation first while transport abstractions mature.
- Full “console parity” workflows are deferred until multi-universe/network transport is production-stable.

