# Roadmap

## Product Direction

FS COS VIS should become a Unified Show Director for small and medium productions: DJ sets, live electronic performances, band FOH operation, rehearsal programming, streaming, and multimedia stage control.

## Phase 0: Stabilize Existing App

- Keep current visualization rendering stable.
- Keep DMX output paths stable.
- Keep project package loading and saving reliable.
- Preserve existing controller protocols.
- Add tests around any touched persistence or runtime services.

## Phase 1: Show Director Core

- Add typed show, setlist, song, section, cue, preset, override, and log models.
- Add schema versioning and migration hooks.
- Add deterministic reducer.
- Add actor-isolated cue execution engine.
- Add fake endpoint adapters and unit tests.
- Add validation for missing presets, impossible transitions, duplicate cue IDs, and unsupported endpoint actions.

## Phase 2: Existing Endpoint Adapters

- Visual scene adapter.
- Palette adapter.
- DMX lighting cue adapter.
- Backdrop video adapter.
- Overlay adapter.
- Recording adapter.
- Utility adapter for blackout, park, restore, and safe look.
- Execution result and health reporting for each adapter.

## Phase 3: Guided Setlist Workspace

- Setlist page for FOH and band shows.
- Current cue and next cue display.
- GO, previous, next, hold, resume, repeat, jump, undo, park, blackout.
- Searchable scene and palette preset browser.
- Insert-next and replace-upcoming live override workflows.
- Execution log view.

## Phase 4: Remote Protocol v2

- Read-only state endpoint.
- GO command.
- Hold/resume commands.
- Preset fire-now, insert-next, and replace-upcoming commands.
- Emergency commands with confirmation semantics.
- WebSocket event stream for cue results and endpoint health.
- iPhone and Apple Watch companion contract.

## Phase 5: DJ and Live Electronic Integration

- Traktor event adapter for track identity, deck state, beat position, and section metadata where available.
- Maschine event adapter for scene/group/pad/macro semantic events where available.
- Ableton Link timing awareness.
- MIDI and OSC mapping for hardware surfaces such as Traktor S2, S5, F1, Maschine, and footswitches.
- Song-aware lighting, video, overlay, and recording cues.

## Phase 6: Media and OBS Expansion

- Backdrop video clip packages and layered visual scenes.
- OBS WebSocket scenes, sources, overlays, markers, and recording state.
- Confidence monitor state.
- Camera preset actions where supported.
- Clean output and stream output separation.

## Phase 7: Assisted Automation

- Section-following helpers.
- Rehearsal timing capture.
- Audio-assisted section estimation.
- AI-assisted cue generation.
- Crowd-aware and energy-aware suggestions.

## Non-Goals for the Near Term

- Writing a custom virtual audio driver.
- Fully automatic live-band section detection as the default path.
- Replacing QLC+, OBS, Core Audio, or existing DMX output services.
- Depending on cloud services during a show.
