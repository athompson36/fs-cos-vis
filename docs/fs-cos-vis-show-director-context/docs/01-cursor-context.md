# Cursor Context

## Repository Mission

`fs-cos-vis` is a macOS SwiftUI/Metal application for live cosmic visuals, stage lighting, and show output. The next major feature family is Unified Show Director: a metadata-driven show-control layer that coordinates visuals, DMX lighting, backdrop media, OBS-style overlays, recording, remote controls, and future DJ/live-band automation.

## Current State

Treat the repository as a late-stage app with existing subsystems, not a blank slate. Expected existing capabilities include:

- SwiftUI app shell and editor surfaces.
- Metal or GPU-backed cosmic visualization rendering.
- Audio analysis, tap tempo, BPM, beat phase, and MIDI clock concepts.
- External display and Syphon-style output paths.
- Lighting patch, fixtures, cue authoring, modulation, verification, and DMX output.
- OpenDMX USB, Art-Net, and sACN concepts.
- HTTP, WebSocket, OSC, and MIDI control surfaces.
- Output recording.
- Project folders and `.cosmicshow.zip` package workflows.

Cursor should inspect the actual code before implementing. Reuse existing services, stores, model names, project persistence, and UI patterns when present.

## Architectural Gap

The missing layer is endpoint-neutral show control. Existing lighting cues are likely DMX-oriented and visual/backdrop cues are likely scene-oriented. The app needs a typed performance timeline where each song section can trigger actions across many endpoints in one deterministic cue package.

## Implementation Rule

Add Show Director above existing systems:

- Do not replace rendering.
- Do not replace DMX output.
- Do not replace project persistence.
- Do not invent an unrelated routing engine if the app already has service boundaries.
- Do not block the UI thread with endpoint I/O.
- Do not make network remotes authoritative.

## Core Concepts

- `ShowDocument`: top-level show package metadata.
- `Setlist`: ordered performance plan.
- `SongScore`: reusable song-level timeline metadata.
- `SongSection`: intro, verse, chorus, solo, breakdown, drop, outro, applause, intermission, custom.
- `CuePackage`: endpoint-neutral set of actions executed together.
- `EndpointAction`: typed action for lighting, visuals, video, overlay, OBS, recording, camera, utility, MIDI, OSC, or audio routing.
- `Preset`: reusable lighting scene, palette, visual scene, video scene, overlay package, or utility look.
- `ShowRuntimeState`: current song, current section, active endpoint state, hold status, overrides, health.
- `ExecutionLog`: durable record of cue commands and results.

## First Coding Milestone

1. Create Codable models and migrations.
2. Create reducer tests before UI.
3. Create fake endpoint adapters.
4. Create actor-isolated execution engine.
5. Wire adapters to existing services.
6. Add basic Guided Setlist UI.
7. Add protocol v2 state and GO command.
8. Persist show packages inside the current project/package system.

## FOH Mode

FOH Setlist mode is not a separate product. It uses the same endpoint actions as DJ mode, but manual or guided setlist cues replace Traktor beatgrid events as the timing source. This is critical for operating lights, visuals, overlays, and recordings while mixing front of house for a live band.
