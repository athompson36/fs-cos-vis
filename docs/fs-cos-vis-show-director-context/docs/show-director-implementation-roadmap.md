# Unified Show Director Implementation Roadmap

## Milestone 1: Models and Schema

Deliverables:

- Codable models for show documents, setlists, songs, sections, cue packages, endpoint actions, presets, overrides, endpoint health, and logs.
- Schema version field.
- Migration entry point.
- Validation for stable IDs, missing references, duplicate cues, unsupported actions, and missing media.

Acceptance:

- Example JSON files decode and encode without loss.
- Invalid references produce useful validation errors.
- Tests cover round-trip encoding.

## Milestone 2: Reducer

Deliverables:

- Pure reducer.
- Commands for GO, previous, next, hold, resume, repeat, jump, fire preset now, insert next, replace upcoming, undo, park, blackout, restore.
- State snapshots suitable for UI and remotes.

Acceptance:

- Unit tests prove deterministic transitions.
- No endpoint service is referenced by reducer.
- Undo restores prior endpoint target state where possible.

## Milestone 3: Execution Engine and Fake Adapters

Deliverables:

- `ShowDirectorEngine` actor.
- Adapter protocol.
- Fake adapters for tests.
- Execution log writer.
- Timeout and partial failure behavior.

Acceptance:

- Multiple GO requests are serialized.
- Duplicate commands are coalesced or rejected predictably.
- Failed endpoint action is logged without corrupting state.

## Milestone 4: Existing App Adapters

Deliverables:

- Visual scene adapter.
- Palette adapter.
- Lighting/DMX cue adapter.
- Backdrop video adapter.
- Overlay adapter.
- Recording adapter.
- Utility adapter.

Acceptance:

- A cue package can trigger at least one action across three endpoint families.
- Health is reported for each wired endpoint.
- Missing endpoint service produces a clean unsupported result.

## Milestone 5: Setlist Workspace

Deliverables:

- Setlist sidebar.
- Current song/section panel.
- Next cue preview.
- Endpoint health panel.
- GO, previous, next, hold, resume, repeat, jump, undo, park, blackout.
- Preset browser with fire now, insert next, replace upcoming.

Acceptance:

- Operator can run a simple band set in Guided mode.
- Manual preset override does not permanently corrupt the show file unless explicitly saved.
- UI remains responsive during endpoint execution.

## Milestone 6: Protocol v2

Deliverables:

- Read-only runtime state endpoint.
- Command endpoint for GO and timeline controls.
- Preset command endpoint.
- WebSocket event stream.
- Command result IDs and idempotency.

Acceptance:

- Browser/iPhone/watch clients can issue semantic commands.
- Emergency commands are distinguishable.
- Reconnect gets current authoritative state.

## Milestone 7: DJ Event Adapters

Deliverables:

- Normalized Traktor event adapter.
- Maschine event adapter.
- Ableton Link timing awareness where available.
- Mapping from song/section metadata to show cues.

Acceptance:

- DJ mode can load song-aware cues without relying on undocumented vendor internals.
- Manual override remains available.

## Milestone 8: Advanced Automation

Deliverables:

- Rehearsal timing capture.
- Assisted section following.
- AI cue generation as an optional editor helper.
- More complete OBS/camera/audio routing adapters.

Acceptance:

- Fully manual show operation remains reliable if automation is disabled.
