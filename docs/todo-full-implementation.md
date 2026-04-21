# TODO — Full Feature Implementation Backlog

Last updated: 2026-04-19

## Audit reference

This backlog was originally derived from the **FS-COS-VIS audit pack** in [`docs/fs-cos-vis-audit-and-docs-update/`](fs-cos-vis-audit-and-docs-update/README_REPLACEMENT.md). Treat that folder as a **historical snapshot**; **live** requirements and status are maintained in root `docs/` (this file, [`project-audit-and-feature-status.md`](project-audit-and-feature-status.md), [`07-roadmap.md`](07-roadmap.md), etc.).

**Intended documentation source-of-truth order** (from audit — keep these mutually consistent after roadmap changes):

1. `README.md`
2. `docs/project-audit-and-feature-status.md`
3. `docs/07-roadmap.md`
4. `docs/todo-full-implementation.md` (this file)
5. `docs/03-ui-ux-spec.md`

**Production readiness (one-pass execution):** [`production-readiness-checklist.md`](production-readiness-checklist.md) — gated checklist, lab/ops gates, doc close-out. Supporting: [`feature-surface-matrix.md`](feature-surface-matrix.md), [`control-schema-coverage.md`](control-schema-coverage.md), [`control-plane-smoke.md`](control-plane-smoke.md), [`uat-checklist.md`](uat-checklist.md), [`dmx-lab-procedures.md`](dmx-lab-procedures.md), [`historical-docs-reconciliation.md`](historical-docs-reconciliation.md). **Gate 7 (canonical doc sync):** refreshed 2026-04-19 across README → audit → this file → roadmap → `03-ui-ux-spec` → `lighting-roadmap` (see checklist).

**Workspace rules** (apply when implementing UI/DMX tasks):

- Live Show: [`.cursor/rules/live_show.mdc`](../.cursor/rules/live_show.mdc) — keep Performance mode visually quiet; do not block the Metal preview with heavy inspectors.
- Scene Studio: [`.cursor/rules/scene_studio.mdc`](../.cursor/rules/scene_studio.mdc) — authoring split preview vs controls is intentional.
- Lighting: [`.cursor/rules/lighting_workspace.mdc`](../.cursor/rules/lighting_workspace.mdc) — DMX via `AppModel.applyDMXPatchDocument` / cue APIs; preserve OFL `channelCapabilities`.

---

## Section A — Documentation coherence

### A.1 README

- [x] Replace README title/subtitle positioning from “Cursor Starter” to **beta / hybrid visualizer + show-control platform** (see audit pack [`README_REPLACEMENT.md`](fs-cos-vis-audit-and-docs-update/README_REPLACEMENT.md)).
- [x] Ensure README “Included” / framing paragraphs match current product (not scaffold-only narrative) while keeping accurate build pointers.

### A.2 `docs/project-audit-and-feature-status.md`

- [x] Full refresh: single place listing shipped features (recorder, setup wizard, beta updates, feedback, OSC, show package import/export, etc.) per audit gap list.

### A.3 `docs/07-roadmap.md`

- [x] Reconcile any duplicate or contradictory bullets vs this backlog and the audit pack `docs/07-roadmap.md`.
- [x] Keep as high-level roadmap **source of truth**; update other docs when roadmap status changes.

### A.4 `docs/lighting-roadmap.md`

- [x] Keep aligned with **actual** Art-Net/sACN/inbound/RDM progress; label scaffold vs production honestly.

### A.5 `docs/03-ui-ux-spec.md`

- [x] Revise IA: **Palette Browser** and **Overlay Manager** are **not** standalone primary screens — document **intentional consolidation into Scene Studio** (do not track as missing pages).
- [x] Align “Performance View” / Live Show required controls with implemented UI; list remaining gaps explicitly (see Section C).
- [x] Reflect **Drew Spaceman** style rule (cosmic / cinematic / immersive; avoid sterile or muddy UI) as non-regression guidance for future UI work.

### A.6 `docs/beta-0.1a-release.md` and `docs/osc-control.md`

- [x] Spot-check cross-links and validation steps against current Settings / OSC / recorder / permissions flows.
- [x] Ensure release runbook references match actual scripts and workflows.

### A.7 macOS installer / distribution docs

- [x] Add or align root-level `docs/macOS-installer-options.md` with audit guidance: **DMG primary** for testers, **ZIP** for Sparkle/appcast, **PKG** non-primary unless product decision changes (content may start from [`fs-cos-vis-audit-and-docs-update/docs/macOS-installer-options.md`](fs-cos-vis-audit-and-docs-update/docs/macOS-installer-options.md)).

### A.8 Backlog self-consistency

- [x] After each major roadmap or feature drop, update this file so open items match reality (audit: avoid drift between roadmap and backlog). *(Process: repeat whenever roadmap or major feature lands.)*

### A.9 Intentional product decisions (documentation)

- [x] Document that **Palette Browser** and **Overlay Manager** live in **Scene Studio** by design (was tracked as P1 spec alignment; see roadmap/todo notes).
- [x] Ensure `docs/03-ui-ux-spec.md` and `docs/project-audit-and-feature-status.md` both state consolidation explicitly for new readers.

---

## Section B — Information architecture and navigation

- [x] **Research / spike:** evaluate **sidebar navigation** vs crowded **TabView** for future scale (audit: optional; no commitment required in first iteration). *(Recorded in [`navigation-ia-spike-notes.md`](navigation-ia-spike-notes.md).)*
- [x] Top-level tabs: Live Show, Scene Studio, Controller, Settings, Lighting — **clear separation** (audit strength; keep as baseline).

---

## Section C — Live Show (performance UX)

**Audit / spec gaps and polish**

- [x] **Explicit audio input meter** (visible level meter in Live Show) — spec “required”; audit flagged gap. *(RMS/peak bar in `LiveShowView`.)*
- [x] **Strong beat pulse / visual beat widget** — beyond BPM confidence text; audit + spec. *(Beat-phase ring from `AppModel.tempoClock.beatPhase`.)*
- [x] **Reorganize top action band** into three groups:
  - [x] Performance actions — *GroupBox “Performance” (`performanceSceneActionsRow`).*
  - [x] Look / palette actions — *GroupBox “Look / palette”.*
  - [x] Capture / output actions (incl. recorder) — *GroupBox “Capture / output”.*
- [x] Move **authoring-heavy overlay utilities** (e.g. import overlay, black-background removal) behind **disclosure or utility menu** — audit: reduce live-row clutter; keep preview unobstructed per `live_show` rule. *(Overlay file tools `Menu` in Performance group.)*
- [x] **Summary strip** for **active scene / palette / cue** (and lighting cue where relevant) — audit “now active” visibility. *(GroupBox “Active”.)*
- [x] Reduce **vertical stack pressure** / busy layout without blocking Metal preview (audit gap). *(Grouped sections + overlay tools in menu; further polish optional.)*

**03-ui-ux-spec required controls (verification against spec)**

- [x] Audio device selector — implemented (`LiveShowView` / `AppModel` audio).
- [x] Input channel selector (mono / stereo / mix) — implemented.
- [x] Audio input meter — RMS/peak meter row.
- [x] BPM readout — implemented.
- [x] Beat indicator / pulse — beat-phase ring + confidence in Performance group.
- [x] Previous / next / random scene — implemented.
- [x] Fullscreen — implemented.
- [x] Quick palette access — implemented.
- [x] Liquid light toggle — implemented.
- [x] Overlay enable / placement toggle — implemented.
- [x] Haze emergency kill — implemented.
- [x] Live recorder controls — implemented (`AppModel` recorder + `LiveShowView`).

**Interaction priorities (spec)**

- [x] Keep **live actions obvious and low-risk**; maintain hierarchy between live vs authoring (ongoing polish). *(Performance / Look / Capture groupings + overlay tools menu.)*
- [x] **Low-light readability** of current state (ongoing; align with Drew Spaceman clarity). *(Guideline; incremental UI tweaks continue as needed.)*

---

## Section D — Scene Studio (authoring UX)

- [x] **Stronger sectional navigation** for dense controls (audit + spec). *(Right column: “Authoring” horizontal chip row + scrollable content in [`SceneStudioView.swift`](../FSDMXVision/FSDMXVision/App/SceneStudioView.swift).)*
- [x] **Segmented or tabbed sub-mode** clarity for: **Scene · Look · Fractal · Liquid · Overlay · Palette** (audit recommends; spec recommended sub-sections). *(Persisted `SceneStudioAuthoringSection` chips + single visible section.)*
- [x] **Collapsible cards** with **persisted expansion state** for heavy sections (audit). *(`@AppStorage` for liquid pour vs palette subsections; overlay files vs overlay cards.)*
- [x] **Consolidation retained**: palette + overlay + fractal + liquid authoring in one surface (defensible; `scene_studio` rule: preview vs controls split).

---

## Section E — Controller (mapping / performance control)

- [x] **Mapping summary cards** — stronger visibility of MIDI/OSC mappings (audit). *(Overview: GroupBox cards for MIDI continuous, MIDI triggers, OSC examples in [`ControllerView.swift`](../FSDMXVision/FSDMXVision/App/ControllerView.swift).)*
- [x] **Filter / search** for fader groups / larger rigs (audit). *(Faders tab: search field filters DMX fixture groups by title or channel label.)*
- [x] **Planned / disabled** control labeling — unambiguous styling (audit). *(“Planned” capsule next to disabled DMX / combined learn modes.)*
- [x] **Visual separation** of: scene parameters vs DMX fixture controls vs learned controls (audit). *(Cyan-tinted “Scene parameters” vs orange-tinted fixture cards; fader captions label MIDI vs DMX manual.)*
- [x] Reduce **raw engineering** feel toward polished operator surface (ongoing). *(Copy + grouping refresh on Overview/Faders; further polish optional.)*

---

## Section F — Settings

- [x] **Basic / Advanced** disclosure (or equivalent) for **transport-heavy** blocks: DMX output, Art-Net/sACN, inbound DMX, RDM (audit). *(Persisted `settings.transportUITier` segmented control; Basic hides scaffold blurbs, live diagnostics, frame timing, and full RDM; Advanced shows them — [`SettingsView.swift`](../FSDMXVision/FSDMXVision/App/SettingsView.swift).)*
- [x] Consider **grouped panes or subpages** if Settings continues to grow (audit: optional). *(DMX area split into titled sub-blocks: output / inbound / RDM; nested GroupBoxes for diagnostics — further tabbing optional.)*
- [x] **Stronger transport diagnostic grouping** (audit “Missing UI” + Settings gaps). *(Advanced: separate GroupBoxes for output stream, inbound receiver, frame timing.)*
- [x] Broad coverage present: beta status, updates, feedback, show package archive, AI, remote, OSC, audio, DMX scaffolds (`SettingsView` / `AppModel`).

---

## Section G — Lighting workspace

- [x] **Sub-navigation** clarity for: **Patch · Cues · Stage · Verify · Tools** (audit + spec; may exceed current two-tab layout). *(Five `TabView` tabs with SF Symbols in [`LightingWorkspaceView.swift`](../FSDMXVision/FSDMXVision/Features/Lighting/LightingWorkspaceView.swift).)*
- [x] Move **JSON transport / import / export** bulk UI to **Tools** or **Advanced** area (audit). *(JSON bundle/patch/stage/cue transport editors live only on **Tools**; group title notes bulk import/export.)*
- [x] **Verification wizard** visually isolated; **easier resume** after interrupt (audit; partial progress exists — harden UX). *(Dedicated **Verify** tab with intro card + tinted background; assisted verification block moved out of Patch; resume copy references **Resume scan**.)*
- [x] **Search / filter** for larger patch/cue sets where practical (audit “Missing UI”). *(Patch: filter fixtures by profile name, address, or fixture index; Cues: filter cue editor list by name; selected cue stays visible when filtered out.)*
- [x] Patch, cues, stage, 2.5D preview, OFL, verification, modulation — implemented baseline (`LightingWorkspaceView`).

---

## Section H — Verification and testing (deterministic / QA)

**Previously completed (evidence in test target)**

- [x] Deterministic tests for **dual-camera** fixture verification flow (primary + secondary fallback) — `FixtureVerificationTests` / related.
- [x] Regression tests for **stage layout camera overlays** and scan-angle persistence — `FixtureVerificationTests` / stage models.
- [x] Coverage for **stage object auto-scaling** vs stage dimensions and JSON migration — tests per backlog.
- [x] Harden **cancellation/resume** for camera disconnect/reconnect — `AppModel` + tests.
- [x] Integration test for **overlay metadata substitution** + **timeout** on cue transitions — `AppModelTests`.

**Remaining / polish (audit “still not complete enough”)**

- [x] **Stronger confidence scoring** and diagnostics for verification (audit: in progress). *(`FixtureVerificationEvaluator.confidence01` / run average; per-fixture % + signal Δ in report; [`FixtureVerificationModels.swift`](../FSDMXVision/FSDMXVision/Features/Expansion/FixtureVerificationModels.swift).)*
- [x] **Final operator UX polish** in stage / verification flows (audit). *(Verify tab: exposure banner + intro; Stage plan: mid-tone exposure tip.)*
- [x] **Low-light / overexposure** scan guidance — baseline messaging done; continue refinement as needed. *(Extra **weak contrast** `exposureHint`; `fixtureVerificationExposureHint` banner on Verify; tests extended.)*

---

## Section I — Transport and DMX (network / desk / performance)

**Lab / field (production Gate 3):** [`dmx-lab-procedures.md`](dmx-lab-procedures.md) — outbound receiver checks, competing-source log, extended sACN PDU notes.

**Open — finish criteria**

- [x] **Multi-universe outbound** via **Art-Net** — one UDP packet per logical fixture universe; **network universe** in Settings is an **offset** added to each logical universe (clamped to protocol limits). `DMXUniverseBuilder.buildPerUniverse`, `AppModel.buildDMXUniversesForNetwork`, `ArtNetTransport.sendUniverseMap`, `DMXOutputService.tick` for `artnet`.
- [x] **Multi-universe outbound** via **sACN** — same wiring (`SACNTransport.sendUniverseMap`, `DMXOutputService` mode `sacn`).
- [ ] **Inbound DMX** “desk-grade” path — **multi-universe** listener + per-logical-universe merge on **network** output shipped (`DMXInputService` range, `AppModel.buildDMXUniversesForNetwork`); USB path still merges **first** configured universe into the single local buffer. **sACN:** per-packet **priority** (E1.31 framing byte): higher priority wins while the stored frame is **fresh** (~3s); stale buffer allows a lower-priority source to take over. Remaining: cross-subnet / full desk parity / field sACN hardening — see Section I notes.
- [ ] **E1.31 / sACN** — **partial:** **outbound** uses full **E1.31** data packet layout (638 bytes, Root/Framing/DMP); **inbound** decodes standard packets and the older app scaffold; **inbound multicast** — `IP_ADD_MEMBERSHIP` / `IP_DROP_MEMBERSHIP` for `239.255.x.y` per listened universe (Wi‑Fi / IGMP); **inbound priority merge** (framing priority) **shipped**; **inbound** recognizes **extended** PDUs (root vector `0x08`) and counts **synchronization** vs **universe discovery** frames for diagnostics (no sync timing / discovery protocol handling yet); deeper field hardening — field-test vs reference receivers where you need guarantees.
- [x] **DMX over Wi‑Fi / LAN (operator path)** — Settings + wizard copy; **inbound sACN** multicast join — [`DMXOutputService.swift`](../FSDMXVision/FSDMXVision/Features/Expansion/DMXOutputService.swift) (`SACNMulticastAddress`, `DMXInputService`).
- [ ] **RDM discovery/probing** beyond **mock/scaffold** — replace or augment `RDMDiscoveryService` mock with real workflow when ready.
- [ ] **Performance profiling** under **larger fixture counts / high modulator density** — **partial:** profiler snapshot + Settings show fixture/modulator/logical-universe counts, **max build/send/total**, **nine-bucket total-time histogram**, **approx. median / p95** for **total**, **build**, and **send** (interpolated from bins), and **Reset stats**; optional **exact streaming quantiles** or richer breakdowns still open.

**Progress notes (keep in sync with code)**

- [x] Initial Art-Net/sACN **scaffolding**, UDP send path, packet builders — extended with **per-universe** send and **pkt/tick** in output diagnostics (`extendedDiagnostics` / Settings / Lighting patch strip); **sACN outbound** now emits **full E1.31** data packets (`DMXNetworkPacketBuilder.makeSACNPacket`).
- [x] Inbound listener, HTP/LPT merge, decode tests — **contiguous multi-universe** listen + per-universe network merge; USB merges configured start universe into universe 0; **sACN priority** respected for competing sources (see open bullets).
- [x] RDM **mock** probe + UI scaffold — partial.
- [x] DMX **runtime profiler** + over-budget frames + **histogram** + **approx. median/p95** + **reset** (`DMXPerformanceProfiler`, Settings).

---

## Section J — Control parity (native / web / MIDI / OSC)

- [x] **Systematic parity audit** — canonical path and surface notes: [`control-parity.md`](control-parity.md). OSC layer + cue/scene/tempo gaps closed (addresses in [`osc-control.md`](osc-control.md) + `OSCControlBusStub.parseCommand`).
- [x] OSC **state query** `/cosmic/state/get` aligned with web state JSON — `OSCControlService` + `AppModel.makeWebStateSnapshotData()`.
- [x] **Web / remote** live recording **start/stop/status** + **latest output path** in state — `RemoteControlCommand`, `WebControlStateDTO`, OSC `/cosmic/recording/*`.
- [ ] **Authenticated API relay** for **feedback issue submission** without storing **GitHub** tokens locally — **partial:** `FeedbackAndLogsService.submitFeedbackIssue` + Settings **relay URL / relay bearer** (client POST); operators can leave `githubFeedbackToken` empty when a relay is configured. **Example relay (Node):** [`scripts/feedback-relay/README.md`](../scripts/feedback-relay/README.md). **Remaining:** deploy that (or equivalent) with HTTPS + server-side GitHub credentials.

**Production readiness ([`production-readiness-checklist.md`](production-readiness-checklist.md) Gate 6):** A hosted relay is **optional**. Closing that gate requires either a successful relay deploy **or** an explicit **deferred** decision (e.g. beta uses local PAT, or feedback disabled) recorded in release notes / operator comms — not a code blocker.

---

## Section K — Release, installer, signing, Sparkle

**Recommended beta path (audit + `macOS-installer-options.md` + [`release-runbook.md`](release-runbook.md))** — Gate 5 table: [`distribution-checklist.md`](distribution-checklist.md).

**Repo / CI (unsigned Release artifacts)**

- [x] **Release** configuration build — `.github/workflows/release-macos-beta.yml` runs `xcodebuild -configuration Release`.
- [x] Package **DMG + ZIP** — `scripts/release/package-beta.sh` (optional `COSMIC_RELEASE_APP` override).

**Requires Apple Developer Program + maintainer action**

- [ ] **Sign** with Developer ID Application — procedure: [`release-runbook.md`](release-runbook.md) (Xcode Organizer path or command-line).
- [ ] **Notarize** successfully — same runbook (`notarytool` + `stapler`).
- [ ] **DMG** to beta testers after sign+notarize (operational handoff).
- [ ] **ZIP** for Sparkle / appcast — signed update bundle + hosted `appcast.xml` (runbook Sparkle section).
- [ ] **Prove end-to-end** signed + notarized pipeline — optional future CI (secrets); **manual gates documented** in [`release-runbook.md`](release-runbook.md).

**Documentation / validation**

- [x] **Sparkle publication** notes — feed URL / edDSA / hosting checklist in [`release-runbook.md`](release-runbook.md); automation TBD when feed URL is fixed in Info plist.
- [x] **Clean Mac without Xcode** — validation bullets in [`release-runbook.md`](release-runbook.md) + [`beta-0.1a-release.md`](beta-0.1a-release.md).
- [x] **PKG installer** — deferred; [`macOS-installer-options.md`](macOS-installer-options.md).

---

## Section L — CI and automation

- [x] **Show package** export/import **smoke** tests in CI — `.github/workflows/show-package-smoke.yml` + `scripts/ci/smoke-show-package.sh` + `ShowProjectAndContextTests` archive roundtrip.
- [ ] Extend CI smoke coverage as new critical paths stabilize (optional incremental).

---

## Section M — Completion criteria

**Beta-ready gates** (revisit when shipping a named release; not every P2 item must close to ship a beta.)

1. [x] **Docs / spec / roadmap / README** agree (no drift) — *pass verified 2026-04-18* ([`project-audit-and-feature-status.md`](project-audit-and-feature-status.md), [`07-roadmap.md`](07-roadmap.md), this file, [`README.md`](../README.md)).
2. [x] **Live** performance UX is clearly separated from **authoring** — *Section C complete*: grouped action bands, audio meter, beat-phase ring, active summary strip, overlay tools in menu; [`live_show` rule](../.cursor/rules/live_show.mdc).
3. [x] **Verification** is reliable, test-backed, and operator-polished for beta — *Section H complete* (deterministic tests, confidence/diagnostics, exposure hints). *[ ] Optional:* deeper CV / geometry beyond heuristics if product scope expands (not blocking beta).
4. [x] **Transport claims match behavior** — **Outbound** Art-Net/sACN multi-universe + offset + diagnostics **shipped**; **sACN outbound** uses full E1.31 framing; UI labels scaffolds where needed. *[ ] Still open:* inbound desk-grade polish (cross-subnet etc.), sACN **sync/discovery protocol** behavior (beyond packet counts), RDM beyond mock, optional **exact** profiler quantiles — see Section I.
5. [ ] **Beta tester** can install and run **without Xcode friction** — *operational:* signed/notarized DMG validated on a clean Mac ([`release-runbook.md`](release-runbook.md)).
6. [x] **OSC / web / MIDI** parity **documented and exercised** — [`control-parity.md`](control-parity.md), [`osc-control.md`](osc-control.md), `POST /api/command` superset; Section J parity audit **[x]**. *[ ] Separate:* authenticated **feedback** relay (Section J) does not block control parity.

**Implementation depth (P0 / P1 / P2)**

1. [x] **P0/P1** stability and operator UX for beta — core surfaces, tests, and runbooks in place; remaining items are **release ops** (Section K) and optional CI expansion (Section L).
2. [x] **P2 transport (partial):** **Outbound** multi-universe + docs **done**; **inbound** multi-universe listen + network per-universe merge + **sACN priority merge** **done**; **sACN** extended sync/discovery **packet counts** in Settings **done**; DMX **frame histogram** + **binned median/p95** (total/build/send) in Settings **done**. *[ ] P2 continues for:* RDM, sACN sync/discovery **protocol** + field verification — Section I.
3. [x] **Control parity** — documented coverage in [`control-parity.md`](control-parity.md); MIDI/web/OSC mapped to `applyRemoteCommand` with honest gaps for settings-only actions.

---

## Appendix — Stub / honest-limit register

Single place for **intentional** stubs, test doubles, and **honest** “not production” boundaries (refresh when code changes). Not every `TODO` in the repo—only items operators or integrators might hit.

| Item | Kind | Where | Notes |
|------|------|-------|-------|
| RDM discovery / parameter fetch | Scaffold | `DMXOutputService`, `RDMDiscoveryService` | Mock/deterministic probe; full USB/RDM stack TBD. |
| sACN sync / discovery PDUs | Counted only | `DMXInputService`, Settings copy | Extended PDUs increment diagnostics; no sync timing / discovery protocol consumer. |
| DMX USB learn (Controller) | UI “Planned” | `ControllerView` | Use HTTP/MIDI/OSC for the same actions until learn ships. |
| `export_fixture_ofl_stub` (LLM tool) | Intentional no-op | `AIToolRegistry` | Returns guidance string; real OFL export is Lighting workspace import flow. |
| Lighting Copilot draft cues | Placeholder | `LightingCopilotService`, Lighting → Tools | `draftCuesFromSongStructurePlaceholder` is structural only, not ML. |
| MIDI/OSC/DMX control **stubs** | Test harness | `ControlBus.swift` | `*Stub` types for unit tests—not missing product features. |
| Feedback HTTPS relay | Deployer-owned | Settings, Section J | Client POST only; server that calls GitHub is out of repo. |

See also: [`ui-page-verification.md`](ui-page-verification.md) (no missing primary screens by design), [`lighting-roadmap.md`](lighting-roadmap.md) (transport lab gates).

---

## Appendix — Quick index of major code anchors

| Area | Primary entry points |
|------|----------------------|
| Live Show | `LiveShowView.swift`, `LiveShowCueStripsView.swift` |
| Scene Studio | `SceneStudioView.swift`, `OverlayCardAuthoringView.swift` |
| Controller | `ControllerView.swift`, `MIDIMapping.swift` |
| Settings | `SettingsView.swift`, `RemoteControlSettings.swift` |
| Lighting | `LightingWorkspaceView.swift`, `AppModel.applyDMXPatchDocument` |
| Web / API | `WebControlServer.swift`, `WebControlStateDTO.swift`, `ControlSchema.swift` |
| OSC | `ControlBus.swift` (`OSCControlService`, `OSCControlBusStub`), [`osc-control.md`](osc-control.md), [`control-parity.md`](control-parity.md) |
| DMX | `DMXOutputService.swift`, `DMXInputService` patterns |
| Show package | `ProjectStack.swift` (`ShowProjectPackage`), `AppModel` save/load project |
| Release / beta | [`release-runbook.md`](release-runbook.md), `scripts/release/package-beta.sh`, `.github/workflows/release-macos-beta.yml` |
