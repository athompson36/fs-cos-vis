# Production & Show Director — consolidated TODO

**Created:** 2026-07-16
**Scope:** Single tracked backlog from current state to production, covering (A) production readiness for the existing app and (B) the Unified Show Director program.

**Audit basis:** Verified locally 2026-07-16 — project builds and the full unit suite passes (`xcodebuild test -project FSDMXVision.xcodeproj -scheme FSDMXVision -destination 'platform=macOS'` → **TEST SUCCEEDED, 234 tests, 0 failures**); the show-package smoke passes **2 tests, 0 failures**. Docs cross-checked against code; findings below. Sources: `docs/production-readiness-checklist.md`, `docs/todo-full-implementation.md`, `docs/07-roadmap.md`, `docs/lighting-roadmap.md`, and `docs/fs-cos-vis-show-director-context/`.

**Legend:** `[ ]` open · `[~]` partial · `[x]` done. Priorities: **P0** ship blocker · **P1** validation gate · **P2** correctness/cleanup · **P3** deferred/optional.

---

## PART A — Production readiness (existing app)

### P0 — Ship blockers (in-repo, no hardware needed unless noted)

**Release engineering & distribution (Gate 5)**

- [x] A1. Add Sparkle keys to Info.plist: `SUFeedURL`, `SUPublicEDKey`, `SUEnableAutomaticChecks`. **Done** (2026-07-16): keys live in a partial [`FSDMXVision/Info-Sparkle.plist`](../FSDMXVision/Info-Sparkle.plist) **merged** with the generated plist via `GENERATE_INFOPLIST_FILE` + `INFOPLIST_FILE` in [`project.yml`](../project.yml). Verified present in the built app's `Contents/Info.plist`. `SUEnableAutomaticChecks=false` (no mid-show prompts; manual "Check for updates").
- [x] A2. Generate Sparkle EdDSA key pair; wire the public key; appcast tooling. **Done** (2026-07-16): keypair generated via Sparkle `generate_keys` (private key in maintainer login Keychain — **back it up, keep off-repo**); public key `h2G3DrLDQTmLO9Nq5fUBu5n9zNPRVhAB6Ml91K85nmM=` in Info-Sparkle.plist; [`scripts/release/generate-appcast.sh`](../scripts/release/generate-appcast.sh) signs + writes `dist/appcast.xml`. **Remaining ops (not code):** host `appcast.xml` at the `SUFeedURL` over HTTPS and confirm the URL matches your hosting (default is a GitHub Pages placeholder).
- [ ] A3. Developer ID Application signing of nested code in order (helpers → Sparkle/Syphon frameworks → app) per `docs/release-runbook.md`. *(Needs Apple Developer account.)*
- [ ] A4. `notarytool submit` + `stapler staple`; record submission ID.
- [ ] A5. Produce DMG (testers) + ZIP (Sparkle) via `scripts/release/package-beta.sh`.
- [ ] A6. Validate on a clean Mac without Xcode (Gatekeeper, mic permission, first-run wizard) per `docs/beta-0.1a-release.md`.
- [x] A7. Set non-empty `INFOPLIST_KEY_NSHumanReadableCopyright`; confirm marketing/build version bump strategy. **Done** (2026-07-16): copyright `Copyright © 2026 FS Tech. All rights reserved.` in [`project.yml`](../project.yml); version bump strategy documented in [`docs/release-runbook.md`](release-runbook.md) (§ Version numbers).

**Security hardening of the remote control plane** (found in code audit; not tracked in any existing doc/gate)

- [x] A8. Add auth gate to `GET /ws` WebSocket — **done** (2026-07-16): `/ws` now requires auth (`authorizedAllowingQuery`); `WebControlServer.swift`.
- [x] A9. Empty `authToken`/`oscAuthToken` = fully open control. **Done** (2026-07-16): HTTP + OSC fail safe to loopback when LAN is requested without a token; Settings shows an orange warning (`WebControlServer.runServer`, `ControlBus.OSCControlService.configure`, `SettingsView`).
- [x] A10. Move GitHub PAT + relay bearer out of plaintext `RemoteControlSettings` JSON into the Keychain. **Done** (2026-07-16): `FeedbackSecretsKeychain`; fields removed from the Codable struct; one-time migration from legacy `UserDefaults`; UI drafts + `submitFeedbackIssue` read from Keychain; secrets no longer emitted by `GET /api/settings`.
- [x] A11. Stop accepting auth via `?token=` query string. **Done** (2026-07-16): API routes are header-only; `?token=` accepted only for the initial page load and WebSocket (browsers can't set WS headers).
- [x] A12. Gate `GET /health` behind auth when a token is set. **Done** (2026-07-16). OSC `/cosmic/state/get` was already token-gated (`OSCControlBusStub.isStateQuery`).

### P1 — Validation gates (need operator/hardware)

- [ ] A13. Gate 4 — Execute UAT end-to-end (`docs/uat-checklist.md`); record Pass/Fail per bullet; fill blockers table (currently placeholder). Include combined remote+OSC+DMX stress.
- [ ] A14. Gate 3a — Outbound lab validation: Art-Net + sACN vs real receivers (universe index, rate vs pkt/tick).
- [ ] A15. Gate 3b.2 — Inbound field log: competing sources / priority behavior vs a real console.
- [ ] A16. Gate 3c.2 — sACN extended sync/discovery PDU field capture (if receivers emit them).
- [ ] A17. Gate 2.2/2.3 — Control-plane smoke on a real desktop session (`scripts/ci/smoke-control-plane.sh`, `scripts/osc/examples.sh`).

### P2 — Documentation drift & code cleanup

- [x] A18. Fix Settings sACN copy — **done** (2026-07-16): reworded to "not sent on output; inbound counted for diagnostics only" (`SettingsView.swift`).
- [x] A19. Refresh stale `docs/control-schema-coverage.md` — **done** (2026-07-16): lighting-cue commands moved to the in-schema list.
- [~] A20. Profiler-quantile status — **done in docs** (2026-07-16): backlog §I notes exact ring quantiles already ship (total/build/send) on `/api/state`; Settings surfaces exact *total* only. Optional remaining: surface exact build/send in Settings UI.
- [x] A21. Document inbound-vs-outbound universe-offset asymmetry — **done** (backlog §I audit-corrections note).
- [x] A22. Document universe-0-only cue/modulation/haze limit — **done** (backlog §I).
- [x] A23. Document outbound sACN single-host behavior — **done** (backlog §I).
- [x] A24. Correct "RDM is mock only" claim — **done** (backlog §I + `lighting-roadmap.md` RDM row).
- [x] A25. Keep test-count references current — **done** (234 tests, 0 failures verified 2026-07-16; `production-readiness-checklist.md`, `audit-execution-record.md`).
- [x] A26. Remove dead code — **done** (2026-07-16): removed `LightingPatchOperation`/`LightingCopilotValidationError`/`validate`; dropped unused `copilot` param from `AIToolRegistry.execute`.
- [x] A27. Friendlier operator error when AI reply is not valid JSON tool calls. **Done** (2026-07-16): `AIToolExecutionError.invalidToolCallReply` with expected-shape copy + reply preview; strips markdown fences; unit tests in `AIToolRegistryTests`.

### P3 — Deferred / optional

- [ ] A28. Deploy HTTPS feedback relay (`scripts/feedback-relay/`) or formally record the "direct PAT / disabled" deferral (Gate 6).
- [ ] A29. Real RDM stack (GET/SET) beyond mock/ArtPoll.
- [ ] A30. sACN sync/discovery protocol handling beyond packet counts.
- [ ] A31. Large-rig DMX soak/trace load test to substantiate "console scale."
- [ ] A32. Deeper CV/geometry fixture verification beyond luma heuristics.
- [ ] A33. Cross-subnet / full desk-grade inbound parity.
- [ ] A34. Navigation IA spike (sidebar vs TabView); Windows feasibility spike.
- [ ] A35. Optional CI: enable signed/notarized pipeline (`notarize-macos-dispatch.yml.example`) once secrets exist.

---

## PART B — Unified Show Director (new feature program)

Source: `docs/fs-cos-vis-show-director-context/`. Build strictly bottom-up. Reducer stays pure (no I/O); endpoint I/O only inside the actor engine via adapters; the Mac host is authoritative; remotes send semantic commands and never own runtime state.

**Codebase reality-check:**
- **Foundation shipped (SD-M0–M3):** typed models, validation/migration, `show-director/` package store, pure reducer, actor engine, fake adapters, execution JSONL — see `Features/ShowDirector/` and the foundation design spec.
- **SD-M4 slice 1 shipped:** real visual-scene, palette, and lighting-cue adapters; AppModel-owned runtime engine; verified three-family acceptance. Recording and overlay services exist in the app, but their Show Director adapters remain deferred.
- **Net-new remaining:** backdrop **video playback**, **OBS** WebSocket, **Traktor/Maschine/Ableton Link**, **iPhone/Apple Watch** companions, **audio-routing profiles**, Guided Setlist UI (SD-M5), remote protocol v2 (SD-M6).

### SD-M0 — Persistence & cross-cutting

- [x] SD-0.1 Extend package with `show-director/{show.json,setlists/,songs/,cue-packages/,presets/,logs/}` + `Media/{video/,images/,overlays/}`. **Done** (2026-07-16): `ShowDirectorPackageStore`; existing `Media/` retained.
- [x] SD-0.2 Package validation warns on missing referenced media. **Done** (`ShowDirectorValidator` severity `.warning`).
- [x] SD-0.3 Phase 0 stabilization tests around persistence/runtime. **Done**: package/archive/log/acceptance tests; full suite green.
- [x] SD-0.4 Add `.cursor/rules/show_director.mdc` to live `.cursor/rules/`. **Done**.
- [x] SD-0.5 Reconcile pack vs live docs. **Done**: live SoT is root docs + `docs/superpowers/specs/2026-07-16-show-director-foundation-design.md`; context pack marked reference-only.

### SD-M1 — Models & schema

- [x] SD-1.1 Codable, versioned, stable-ID models. **Done** under `Features/ShowDirector/Models/` (`ShowDirectorMetadata` avoids colliding with project `ShowMetadata`).
- [x] SD-1.2 Typed enums for section types and endpoint/action types. **Done** (`EndpointAction` custom Codable).
- [x] SD-1.3 `schemaVersion` + migration entry point. **Done** (`ShowDirectorMigrator`).
- [x] SD-1.4 Validation for IDs/refs/duplicates/unsupported actions/missing media. **Done**.
- [x] SD-1.5 Round-trip encode/decode tests + useful invalid errors. **Done** (`ShowDirectorModelTests`, `ShowDirectorValidationTests`).

### SD-M2 — Pure reducer

- [x] SD-2.1 Pure reducer `(state, command) -> ShowDirectorReduction`. **Done** (`ShowDirectorReducer`).
- [x] SD-2.2 Command set including separate `blackoutLighting` / `blackoutVideo`. **Done**.
- [x] SD-2.3 Runtime snapshots + bounded undo. **Done**.
- [x] SD-2.4 Deterministic-transition unit tests. **Done** (`ShowDirectorReducerTests`).

### SD-M3 — Execution engine + fake adapters

- [x] SD-3.1 `ShowDirectorEngine` actor with serialize/timeout/dedupe/publish. **Done**.
- [x] SD-3.2 `ShowEndpointAdapter` + execution result statuses. **Done**.
- [x] SD-3.3 Durable execution-log writer. **Done** (`ShowDirectorExecutionLogStore`).
- [x] SD-3.4 Fake adapters + tests. **Done** (`FakeShowEndpointAdapter`, engine + foundation acceptance tests).

### SD-M4 — Real endpoint adapters (wrap existing services)

- [x] SD-4.1 `VisualSceneEndpointAdapter` → `SceneManager`. **Done** (2026-07-16): stable scene UUID recall with mutation read-back verification.
- [x] SD-4.2 `PaletteEndpointAdapter` → palette stores. **Done** (2026-07-16): stable palette UUID selection with mutation read-back verification.
- [~] SD-4.3 Lighting adapter. **Lighting-cue recall done** (2026-07-16): stable cue UUID resolution and verified activation through existing cue semantics. **Still open:** intensity, movement, strobe, kill-strobe, blackout/park/restore-safe-look, and explicit safety limits.
- [ ] SD-4.4 `BackdropVideoEndpointAdapter` — **net-new**: `AVPlayer`-based clip playback (play/loop/transition/opacity/blackout) to preview + external/Syphon output.
- [ ] SD-4.5 `OverlayEndpointAdapter` → overlay cards (lower-third/lyrics/logo/title/hide-all).
- [ ] SD-4.6 `RecordingEndpointAdapter` → `CaptureSession` (start/stop/marker/naming).
- [ ] SD-4.7 `UtilityEndpointAdapter` (house look, intermission, applause, safe mode).
- [~] SD-4.8 Per-endpoint health reporting. **Done for visual scene, palette, and lighting cue**; full endpoint coverage and missing-service `unsupported` handling remain open.
- [x] SD-4.9 Acceptance: one cue package fires ≥3 endpoint families. **Done** (2026-07-16): `ShowDirectorThreeFamilyAcceptanceTests` passed for ordered visual-scene, palette, and lighting-cue execution.

### SD-M5 — Guided Setlist workspace

- [ ] SD-5.1 Setlist page: current show, ordered setlist sidebar, current song/section, next-cue preview + major actions, elapsed time, endpoint-health panel, active overrides.
- [ ] SD-5.2 Transport: GO, previous, next, hold, resume, repeat, jump, undo, park, blackout — safety controls prominent, never buried.
- [ ] SD-5.3 Searchable preset browser: fire-now, insert-next, replace-upcoming.
- [ ] SD-5.4 Execution-log view.
- [ ] SD-5.5 Live band flows: hold indefinitely, repeat/extend section, jump-to-any, skip song, insert announcement/encore, park, undo, continue-after-reconnect.
- [ ] SD-5.6 Manual override doesn't corrupt the show file unless explicitly saved; UI stays responsive during execution.

### SD-M6 — Remote protocol v2

- [ ] SD-6.1 Read-only runtime-state endpoint; WebSocket event stream (cue results + endpoint health).
- [ ] SD-6.2 Semantic command endpoints: `GO_NEXT_CUE`, `HOLD_TIMELINE`, `RESUME_TIMELINE`, `JUMP_TO_SECTION`, `FIRE_PRESET_NOW`, `INSERT_PRESET_NEXT`, `REPLACE_UPCOMING_CUE`, `PARK`, `BLACKOUT_LIGHTING`, `BLACKOUT_VIDEO`, `RESTORE_SAFE_LOOK`.
- [ ] SD-6.3 Command IDs + idempotency; accepted/rejected/executed/failed status; `expectedRuntimeRevision` handling; reconnect returns authoritative state.
- [ ] SD-6.4 Emergency commands explicitly distinguishable.
- [ ] SD-6.5 iPhone companion contract (full remote operation surface).
- [ ] SD-6.6 Apple Watch companion (eyes-off: GO/prev/next/hold/resume/quick looks/palettes/blackouts/stop-movement/kill-strobe/restore) with press-and-hold confirm on destructive actions.
- [ ] SD-6.7 Remotes cache enough state to recover gracefully; no cloud dependency during a show.

### SD-M7 — DJ / live-electronic integration

- [ ] SD-7.1 Normalized `PerformanceEvent` model; **Traktor** adapter (track/deck/BPM/beat-bar-phrase/hot-cue/loop/remix-cell) via MIDI/OSC/mapping/export metadata — no private internals.
- [ ] SD-7.2 **Maschine** adapter (project/scene/group/pad/macro/transport).
- [ ] SD-7.3 **Ableton Link** timing awareness.
- [ ] SD-7.4 MIDI/OSC hardware mappings (S2/S5/F1/Maschine/footswitches).
- [ ] SD-7.5 Map song/section metadata → cue packages; manual override always available.

### SD-M8 — Media/OBS + assisted automation

- [ ] SD-8.1 **OBS WebSocket** adapter: scene switch, source toggle, text/source props, record start/stop, marker, virtual-cam/stream; failures logged without stopping lights/visuals.
- [ ] SD-8.2 Confidence-monitor vs clean-output separation; camera preset recall where supported.
- [ ] SD-8.3 **QLC+** interop via OSC/MIDI/Art-Net/sACN (recall scenes, chases, master intensity).
- [ ] SD-8.4 **Audio-routing profiles** via Core Audio: detect devices, validate BlackHole/Loopback, recall aggregate/multi-output, explain missing devices, musical→technical channel mapping (no custom driver).
- [ ] SD-8.5 Backdrop video clip packages + layered visual scenes.
- [ ] SD-8.6 Assisted automation (optional, non-default): rehearsal timing capture, section-following, audio-assisted section estimation, AI cue generation, energy-aware suggestions — fully-manual operation must remain reliable if disabled.

**SD definition of first success:** operator creates a setlist, assigns sections with lighting/visual/video/overlay actions, presses GO through the set, holds/jumps as the band changes, fires a manual preset, and later inspects the execution log.

---

## Suggested sequencing

1. **Now (in-repo):** Part A P0 security (A8–A12) + Sparkle Info.plist (A1–A2); Part A P2 doc/cleanup (A18–A27).
2. **Parallel (pure Swift, no hardware):** SD-M1 → SD-M2 → SD-M3.
3. **Then:** Continue deferred SD-M4 adapters (including net-new video, overlay, recording, utility, and safety expansion) → SD-M5 (Setlist UI).
4. **Release ops (needs Apple account):** A3–A7.
5. **Hardware/operator when available:** A13–A17.
6. **Later:** SD-M6 (protocol v2 + phone/watch) → SD-M7 (DJ) → SD-M8 (OBS/QLC+/audio/automation); Part A P3.
