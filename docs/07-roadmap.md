# Roadmap

**Status snapshot:** 2026-07-16

Keep aligned with [`project-audit-and-feature-status.md`](project-audit-and-feature-status.md), [`todo-full-implementation.md`](todo-full-implementation.md), [`03-ui-ux-spec.md`](03-ui-ux-spec.md), and the Unified Show Director documents.

## Completed foundation

- Audio input picker, channel selection, live FFT/RMS/peak/flux, BPM, beat confidence, tap tempo, manual tempo, and MIDI clock
- Fractal + liquid-light Metal render stack with compositing and palette controls
- Extended fractal zoom modes and audio-reactive parameter system
- Live Show and Scene Studio with external display routing
- Live output recorder with source and quality controls
- Scene persistence, overlays, transitions, palettes, and performance workflow refinements
- Setup wizard, beta update, feedback, and project import/export support
- MIDI mapping, HTTP/WebSocket control, OSC listener, state snapshots, and control-parity documentation
- Show project folder and `.cosmicshow.zip` archive support
- Lighting vertical slice:
  - fixture library and patching
  - lighting cues and crossfades
  - bookmark metadata and overlay substitution
  - modulation runtime
  - stage layout and 2.5D preview
  - fog/haze learn and emergency kill
  - OFL import and curated fallback catalog
  - fixture verification workflow
  - USB/OpenDMX, Art-Net, sACN outbound and inbound foundations
- Syphon output for OBS/VJ interoperability
- CI definitions, packaging scripts, UAT/control-plane/DMX lab procedures, and release runbooks

## Existing-beta hardening still open

- Real signed and notarized distribution proof on a clean Mac
- Operator UAT in the intended performance environment
- DMX field/lab gates where hardware certification matters
- RDM beyond the current mock/scaffold
- deeper sACN synchronization/discovery behavior and field hardening
- optional hosted feedback relay
- optional larger-rig profiling and expanded CI smoke coverage

These items remain separate from the new Show Director scope and must not be obscured by new feature development.

## Next major initiative — Unified Show Director

The product will evolve from related visual/lighting control surfaces into one endpoint-neutral show runtime supporting DJ/original-performance and FOH/live-band operation.

Authoritative documents:

- [`show-director-product-spec.md`](show-director-product-spec.md)
- [`show-director-architecture.md`](show-director-architecture.md)
- [`show-director-implementation-roadmap.md`](show-director-implementation-roadmap.md)
- [`show-director-integrations.md`](show-director-integrations.md)
- [`show-control-json-examples.md`](show-control-json-examples.md)

### Phase order

1. **Contracts and migrations** — typed setlist, song score, show cue, action, preset, runtime, override, and log models.
2. **Cue runtime** — deterministic reducer, actor-isolated execution engine, idempotency, undo, endpoint adapters, project persistence.
3. **macOS Setlist** — Guided-mode FOH workflow, current/next cue, GO, hold, jump, park, preset overrides, rehearsal timing.
4. **Multimedia endpoints** — backdrop video, named overlay packages, OBS WebSocket control.
5. **Versioned remote protocol** — v2 HTTP/WebSocket, OSC/MIDI semantic show commands, bundled web client.
6. **iPhone companion** — full remote operation and authoritative state resync.
7. **Apple Watch companion** — minimal cue/safety surface with host acknowledgement.
8. **DJ integration** — normalized Traktor/Maschine/clock/track events and track-aware song scores.
9. **Audio routing coordinator** — guided Core Audio routing presets around installed virtual/physical devices.
10. **Assisted authoring** — reviewed song-section suggestions, rehearsal learning, typed AI draft tools.

## Immediate implementation milestone

The first coding slice should include only:

- typed models and migration tests
- deterministic reducer
- fake endpoint adapters
- serialized cue engine
- visual, palette, lighting, overlay, and backdrop adapters using existing APIs
- new project package files
- simple macOS Guided-mode Setlist operator view
- v2 show state and GO endpoint
- full test and documentation sync

Do not begin with Watch, autonomous AI, or a custom virtual audio driver.

## Product boundaries

- The app coordinates Traktor and Maschine; it does not replace them.
- The app may guide or manage routing around Core Audio devices; it does not provide a virtual audio driver unless one is actually shipped.
- Syphon output and OBS control are complementary; controlling OBS does not replace OBS composition.
- Audio-derived track/section inference is lower-confidence fallback, not equivalent to deterministic metadata.
- Fully automatic FOH behavior is appropriate only for deterministic playback/timecode workflows; Guided mode is the live-band default.

## Long-range options

- deeper CV/geometry fixture verification
- cross-platform feasibility spike
- plugin or bridge components for richer host metadata
- PTZ/camera, audio-console, and generic show-control endpoint adapters
- AI-assisted show draft generation and post-show analysis
