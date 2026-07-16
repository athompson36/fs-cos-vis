# Project audit and feature status

**Last updated:** 2026-07-16

Single-place summary of what the product is today, what remains open in the existing beta, and what belongs to the new Unified Show Director roadmap.

## Product positioning

- **FS DMX Vision** (repo: FS-COS-VIS) is a **late-stage beta native macOS application**: hybrid real-time visualization, lighting, and live/show control.
- It is not a Cursor starter template.
- Palette creation/selection and overlay authoring live in **Scene Studio** by design; they are not missing standalone screens.
- Unified Show Director is the approved next architecture phase, not a shipped feature set.

## Implemented — visualization and UI

- Scene library, scene editing, cue strips, and transitions
- Fractal, liquid-light, and hybrid Metal rendering
- Palette/theme systems and infinite zoom motion modes
- Live Show and Scene Studio operator/authoring split
- External display routing and fullscreen presentation
- Vendored Syphon integration
- Overlay asset/card authoring and black-background removal tools

## Implemented — audio and tempo

- Input device enumeration and selection
- stereo-pair, mono, and mix-all channel modes
- FFT, RMS, peak, flux, band energies, BPM, and beat confidence
- manual BPM, tap tempo, audio detection, and MIDI-clock tempo sources
- microphone permission recovery flows
- optional forwarding of selected input to a selected Core Audio output

The current audio engine is not a general application-to-application virtual patch bay and does not provide a virtual audio driver.

## Implemented — live output and capture

- main-preview or external-output recording
- performance/balanced/archival quality presets
- project-local recording paths
- share/reveal and permission/health indicators
- recording control/status over web and OSC
- Syphon output for OBS/VJ consumption

## Implemented — control and integration

- native Controller surface
- authenticated local HTTP and WebSocket control
- web state/schema and bundled web client
- MIDI mappings and device integration
- OSC UDP control and state query
- setup wizard and provider-aware optional AI onboarding
- remote port scanning/persistence

The current control protocol is a flat command DTO suitable for existing commands. It does not yet provide versioned setlist/show-control commands, command idempotency, companion pairing, or state-version conflict handling.

## Implemented — AI-assisted features

- optional OpenAI-compatible or Anthropic JSON tool-call assistant with Keychain-stored key
- typed tool registry for selected patch/cue/context operations
- local heuristic Lighting Copilot functions

The current song-structure cue drafting path is a placeholder and must not be described as production ML or automatic show scoring.

## Implemented — lighting and DMX

- fixture profiles/instances, patch persistence, and conflict audit
- lighting cues and crossfades
- cue bookmark metadata and overlay text substitution
- modulation runtime and fixture/role target resolution
- stage layout, 2D editing, 2.5D preview, backdrop cues, and stage objects
- fog/haze learn, cue envelopes, and emergency kill
- OFL import, curated catalog, and fallback fixtures
- fixture verification workflow and reports
- JSON import/export tools
- USB/OpenDMX output and optional inbound serial path
- Art-Net and sACN multi-universe outbound
- Art-Net/sACN inbound listener and merge foundations
- DMX runtime profiling and diagnostics

Honest limits remain: RDM is mock/scaffold; deeper sACN sync/discovery protocol behavior and field hardening remain open; hardware claims require lab/field evidence.

## Implemented — projects, packaging, and release infrastructure

- show project folders with project/scenes/controls/patch/cues/backdrop/modulation/stage/overlay JSON and Media directory
- `.cosmicshow.zip` import/export
- show-package smoke workflow and macOS unit-test workflow definitions
- release packaging, signing/notarization runbooks, Sparkle-oriented update support, and feedback bundles

Workflow definitions and documentation do not prove that every workflow, clean-Mac release, or hardware gate has been run successfully in the current environment.

## Existing beta gaps

- complete operator UAT in the intended environment
- signed/notarized clean-Mac distribution proof
- DMX field/lab gates where required
- RDM beyond mock
- deeper sACN synchronization/discovery and reference-receiver validation
- optional hosted feedback relay
- optional larger-rig profiling and broader CI smoke coverage
- optional deeper CV/geometry verification

## New requested expansion — Unified Show Director

The following are **not implemented yet** and are tracked in the dedicated roadmap:

- endpoint-neutral typed show cues and actions
- deterministic show-state reducer and serialized execution engine
- setlist, song-score, section, preset, runtime-override, and execution-log documents
- macOS Setlist workspace with Guided/manual/timed/track-aware modes
- one cue coordinating lighting, visual scene, palette, backdrop video, overlay, OBS, and utilities
- true backdrop video transport
- OBS WebSocket control
- versioned v2 show-control HTTP/WebSocket protocol
- command idempotency and state-version conflict handling
- iPhone companion
- Apple Watch companion
- normalized Traktor and Maschine event adapters
- Ableton Link clock-source investigation
- general audio-routing coordinator around installed Core Audio devices
- rehearsal timing capture and reviewed assisted section/cue authoring

Authoritative new-scope documents:

- [`show-director-product-spec.md`](show-director-product-spec.md)
- [`show-director-architecture.md`](show-director-architecture.md)
- [`show-director-implementation-roadmap.md`](show-director-implementation-roadmap.md)
- [`show-director-integrations.md`](show-director-integrations.md)
- [`show-control-json-examples.md`](show-control-json-examples.md)
- [`.cursor/rules/show_director.mdc`](../.cursor/rules/show_director.mdc)

## Architectural audit conclusion

The correct strategy is an extension, not a rewrite. Existing scenes, lighting cues, palettes, backdrop cues, overlays, project packages, tempo state, HTTP/WebSocket, OSC, MIDI, external output, recording, Syphon, and DMX systems are usable endpoint foundations.

The principal architectural gap is that those systems are coordinated independently and several current cues are domain-specific. The project needs a typed show-control layer that:

- separates cue sources from endpoint destinations,
- uses stable UUID references,
- owns deterministic runtime state,
- serializes effects through adapters,
- distinguishes authored state from runtime overrides,
- logs every run,
- preserves backward compatibility,
- and remains authoritative when companion clients disconnect or reconnect.

## Documentation alignment rule

For current shipped status use this file. For implementation sequence use `07-roadmap.md` and `show-director-implementation-roadmap.md`. For detailed architecture use `show-director-architecture.md`. Historical audit packs remain snapshots and must not override root documentation.
