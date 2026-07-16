# Unified Show Director — Implementation Roadmap

**Audit date:** 2026-07-16  
**Branch context:** `agent/show-control-context`  
**Status:** Planning and implementation specification; features in this document are not shipped unless explicitly marked **Existing**.

## 1. Executive status

FS DMX Vision is a late-stage native macOS beta with a strong implemented foundation:

- SwiftUI application shell and operator workspaces
- Metal visualization engine and external output
- scene, palette, overlay, lighting, backdrop, stage, and modulation documents
- audio analysis, BPM, beat phase, tap tempo, and MIDI clock
- USB/OpenDMX, Art-Net, and sACN lighting paths
- HTTP, WebSocket, OSC, and MIDI control
- project folders and `.cosmicshow.zip` packages
- live output recording and Syphon output

The new Unified Show Director scope is **not yet implemented**. The central missing abstraction is a typed, endpoint-neutral show timeline that coordinates existing and future systems.

### Current readiness by area

| Area | Status | Notes |
|---|---|---|
| Visual scene authoring/output | Existing | Reuse `VisualizationScene`, renderer, external output, transitions. |
| DMX patch/cues/modulation | Existing beta | Reuse; field and RDM limits remain documented separately. |
| Backdrop still-image cues | Existing baseline | Extend to true video playback and transport. |
| Overlay cards/metadata | Existing baseline | Extend to addressable overlay packages and show actions. |
| HTTP/WebSocket/OSC/MIDI | Existing baseline | Add versioned semantic show-control protocol. |
| Tempo/BPM | Existing baseline | Audio/manual/tap/MIDI clock. Ableton Link and host adapters are new. |
| Show project packaging | Existing baseline | Add versioned setlist, cue, score, preset, and run files. |
| Unified show cue engine | Missing | Highest-priority architectural work. |
| Setlist workspace | Missing | New macOS primary surface. |
| OBS WebSocket integration | Missing | Syphon exists; external OBS control does not. |
| Backdrop video engine | Missing | Current backdrop model is image/stage-snapshot based. |
| Traktor/Maschine metadata | Missing | Use adapter boundary; do not hard-code assumptions. |
| iPhone companion | Missing | New target after host protocol is stable. |
| Apple Watch companion | Missing | New target after iPhone/host sync works. |
| General virtual audio routing | Missing | Existing forwarding is not an inter-app patch bay. |

## 2. Priority model

- **P0:** Required to create a reliable unified runtime.
- **P1:** Required for the first usable FOH/DJ beta.
- **P2:** Important integration and operator improvements.
- **P3:** Experimental or advanced automation.

The project should advance by acceptance gates, not estimated dates.

---

## Phase 0 — Contracts, migration plan, and test harness

**Priority:** P0  
**Goal:** Freeze the new architecture before adding live behavior.

### Work

- [ ] Add `ShowControl` feature folder structure.
- [ ] Add typed models for setlists, song scores, show cues, actions, presets, runtime state, overrides, and execution logs.
- [ ] Define explicit Codable version/migration policy.
- [ ] Add fake adapters and fake clock for deterministic tests.
- [ ] Define action failure policies: required, best-effort, deferred.
- [ ] Define stable ID/reference rules for scenes, lighting cues, palettes, backdrop cues, overlay packages, and media.
- [ ] Define project-relative media path validation and missing-asset behavior.
- [ ] Add `show_director.mdc` Cursor rule.

### Gate 0 acceptance

- All new model documents round-trip through JSON.
- Older `.cosmicshow.zip` packages decode without new files.
- Invalid references produce validation findings rather than crashes.
- No endpoint calls exist in views or reducers.

---

## Phase 1 — Deterministic cue engine and project persistence

**Priority:** P0  
**Goal:** Execute one typed cue across existing in-process endpoints.

### Work

- [ ] Implement `ShowStateReducer`.
- [ ] Implement actor-isolated `ShowDirectorEngine`.
- [ ] Implement serialized action execution and idempotent command handling.
- [ ] Implement execution log and complete prior-state snapshots for undo.
- [ ] Implement runtime override stack.
- [ ] Add adapters for existing visual scenes, palettes, lighting cues, backdrop cues, overlays, recording, and utility safety actions.
- [ ] Add UUID-based public activation APIs where current code accepts list indexes only.
- [ ] Extend `ShowProjectPackage` with:
  - `setlist.json`
  - `song_scores.json`
  - `show_cues.json`
  - `show_presets.json`
  - `show_settings.json`
- [ ] Save run artifacts under `Artifacts/Runs/<run-id>/`.
- [ ] Extend archive smoke tests.

### Gate 1 acceptance

A test show can:

1. load from a project package,
2. execute one cue that changes visual scene, palette, lighting cue, backdrop cue, and overlay,
3. write a successful execution log,
4. undo to the complete prior state,
5. save/export/import and produce the same result.

---

## Phase 2 — macOS Setlist and operator runtime

**Priority:** P1  
**Goal:** Deliver a practical FOH Guided-mode workflow on the Mac.

### Work

- [ ] Add Setlist top-level workspace or documented sidebar equivalent.
- [ ] Add setlist editor for songs, utility entries, walk-on, intermission, and encore.
- [ ] Add song-section editor.
- [ ] Add current/next cue operator panel.
- [ ] Add GO, previous, next, hold, resume, jump, repeat, undo, and park.
- [ ] Add cue/preset validation before entering Run mode.
- [ ] Add run revision lock and non-destructive runtime overrides.
- [ ] Add preset browser with Fire now / Insert next / Replace upcoming.
- [ ] Add endpoint-health strip and warnings.
- [ ] Add rehearsal timing capture and observed-duration review.
- [ ] Add keyboard shortcuts and accessible focus order.

### Gate 2 acceptance

An operator can build, rehearse, save, reopen, and run a multi-song setlist without editing JSON. An unexpected extended solo can be held, manually relit, and resumed without corrupting the authored show.

---

## Phase 3 — Media and endpoint expansion

**Priority:** P1  
**Goal:** Make cue packages genuinely multimedia.

### 3A — Backdrop video

- [ ] Create isolated AVFoundation video playback service.
- [ ] Support project-relative clips, preload, loop, pause, stop, seek, and fade/transition.
- [ ] Render video through the existing output/compositor architecture where practical.
- [ ] Define missing-codec and missing-file fallbacks.
- [ ] Add video blackout independent of lighting blackout.

### 3B — Overlay packages

- [ ] Support multiple named overlay documents/packages.
- [ ] Add show actions for show/hide, metadata update, timeout, and clear transient overlays.
- [ ] Preserve existing overlay-card migration.

### 3C — OBS WebSocket

- [ ] Add isolated OBS client with authentication and reconnect.
- [ ] Add request/response correlation and capability discovery.
- [ ] Add actions for scene switch, source visibility, transition, mute, recording, streaming, and markers where supported.
- [ ] Keep Syphon output independent and usable when OBS control is disconnected.

### Gate 3 acceptance

One cue can preload and transition a video, switch lighting and visual scenes, update an overlay, and switch an OBS scene. OBS failure can be configured best-effort without blocking local show output.

---

## Phase 4 — Versioned remote show-control API and web client

**Priority:** P1  
**Goal:** Make every remote client use the same semantic runtime.

### Work

- [ ] Preserve legacy `/api/command`.
- [ ] Add `/api/v2/show/state`.
- [ ] Add `/api/v2/show/command` with command IDs, client IDs, sequence numbers, and expected state version.
- [ ] Add setlist/preset summary endpoints.
- [ ] Add acknowledgements and rejection reasons.
- [ ] Add WebSocket state updates based on change/version, not a fixed 20 Hz full snapshot forever.
- [ ] Add duplicate-command replay protection.
- [ ] Add client reconnect/resync tests.
- [ ] Update bundled web control with setlist GO and presets.
- [ ] Extend OSC with show-control routes while preserving current `/cosmic/*` routes.
- [ ] Add MIDI trigger targets for GO/hold/undo/park/presets.

### Gate 4 acceptance

Native Mac UI, web UI, HTTP, OSC, and MIDI can all fire the same show cue and report the same resulting state version.

---

## Phase 5 — iPhone companion

**Priority:** P1  
**Goal:** Full wireless FOH remote with reliable state synchronization.

### Work

- [ ] Add iOS target/shared model package.
- [ ] Implement discovery and authenticated host pairing.
- [ ] Show current song/section, active cue, next cue, run mode, and endpoint warnings.
- [ ] Implement GO/previous/next/hold/resume/undo/park.
- [ ] Implement preset and palette browser.
- [ ] Implement setlist skip/reorder/insert controls with host validation.
- [ ] Cache active show summaries for brief disconnections.
- [ ] Add connection-loss UI and automatic resync.
- [ ] Require confirmation for destructive/safety actions.

### Gate 5 acceptance

The iPhone can disconnect for a short interval, reconnect, discard stale assumptions, and resync to the authoritative Mac state without duplicating a cue.

---

## Phase 6 — Apple Watch companion

**Priority:** P2  
**Goal:** Eyes-off manual cueing with constrained safety.

### Work

- [ ] Add watchOS target sharing the semantic protocol.
- [ ] Current/next cue glance.
- [ ] GO/previous/next/hold/resume.
- [ ] Quick look/palette/energy presets.
- [ ] Press-and-hold safety actions.
- [ ] Haptic acknowledgement of accepted/rejected commands.
- [ ] Route through iPhone where appropriate, with direct-host fallback only if justified.

### Gate 6 acceptance

A Watch command receives a clear acknowledgement and cannot silently execute twice during connectivity changes.

---

## Phase 7 — DJ, Traktor, and Maschine integration

**Priority:** P2  
**Goal:** Drive the same show timeline from electronic-performance events.

### Work

- [ ] Add normalized `TrackEventSource` protocol.
- [ ] Add operator-selected track identity and score loading.
- [ ] Add MIDI clock/transport input as deterministic tempo baseline.
- [ ] Add OSC/MIDI bridge mapping for deck/track/section commands.
- [ ] Add Traktor adapter only around verified available signals; do not imply unsupported private APIs.
- [ ] Add Maschine event adapter for patterns/scenes/groups when exposed through MIDI/OSC or companion bridge.
- [ ] Add track identity matching by stable ID/file URL/artist-title fingerprint.
- [ ] Add audio-analysis fallback with confidence display.
- [ ] Add automatic, guided, and manual override policy per song.
- [ ] Investigate Ableton Link as a tempo/phase source behind the clock-source interface.

### Gate 7 acceptance

Loading or identifying a scored song selects its show score, follows deterministic beat/transport data when available, enters authored sections, and remains manually overrideable at all times.

---

## Phase 8 — Audio routing coordinator

**Priority:** P2  
**Goal:** Make Maschine-to-Traktor routing understandable and repeatable without claiming to be a virtual audio driver.

### Work

- [ ] Add `AudioRoutingCoordinator` separate from analysis `AudioEngine`.
- [ ] Detect virtual audio and physical Core Audio devices.
- [ ] Add named routing presets such as DJ, DJ + Maschine, and recording.
- [ ] Validate sample rate, channel count, device availability, and feedback-loop risks.
- [ ] Provide guided setup for Maschine output -> virtual device -> Traktor Live Input.
- [ ] Investigate supported Aggregate/Multi-Output Device management.
- [ ] Persist routing intent and repair suggestions, not fragile numeric device IDs alone.
- [ ] Clearly identify any user-installed driver dependency.

### Gate 8 acceptance

A saved routing preset can detect missing devices, explain the required change, and validate signal flow without changing unrelated system audio configuration silently.

---

## Phase 9 — Assisted authoring and show intelligence

**Priority:** P3  
**Goal:** Reduce programming effort while preserving operator authority.

### Work

- [ ] Import song structure markers from supported files/workflows.
- [ ] Suggest sections from audio analysis with confidence and review UI.
- [ ] Generate draft cue packages from existing presets.
- [ ] Learn rehearsal timing observations.
- [ ] Suggest lighting/visual intensity changes without auto-publishing.
- [ ] Add natural-language preset search and draft generation through existing typed AI tool registry.
- [ ] Add execution-run comparison and post-show notes.

### Gate 9 acceptance

AI/heuristics produce editable drafts only. No generated show action can become live without schema validation and explicit operator review or a previously authorized automation rule.

---

## 3. Cross-cutting requirements

### Safety

- [ ] Haze emergency kill remains a final, non-bypassable override.
- [ ] Lighting blackout and video blackout are separate.
- [ ] Strobe and movement kill commands are available on every operator surface.
- [ ] Park is a safe authored state, not an arbitrary last scene.

### Backward compatibility

- [ ] Existing project folders remain loadable.
- [ ] Existing HTTP/OSC/MIDI commands remain valid.
- [ ] Existing Live Show cue strips remain functional during migration.
- [ ] Project migrations are covered by tests.

### Performance

- [ ] Show-control work never blocks Metal frame rendering.
- [ ] Video decode and network endpoints remain off the main actor.
- [ ] Cue dispatch latency and endpoint completion are measured separately.
- [ ] State snapshots do not serialize large media or DMX arrays unnecessarily.

### Documentation

- [ ] Update README, audit, roadmap, TODO, UI spec, control parity, and package format as each phase lands.
- [ ] Mark planned behavior honestly until implemented and verified.
- [ ] Record manual field gates separately from deterministic CI tests.

## 4. Recommended first implementation slice

The first coding milestone should be deliberately narrow:

1. typed models,
2. reducer,
3. fake adapters,
4. visual + lighting + palette adapters,
5. project persistence,
6. a simple Setlist operator screen,
7. v2 HTTP GO/state,
8. comprehensive tests.

Do not begin with Watch, AI section detection, or a custom audio-routing UI. Those depend on a stable host runtime and protocol.
