# TODO — Full Feature Implementation Backlog

Last updated: 2026-04-17

## Audit reference

This backlog is derived from and aligned with the **FS-COS-VIS audit pack** in [`docs/fs-cos-vis-audit-and-docs-update/`](fs-cos-vis-audit-and-docs-update/README_REPLACEMENT.md) (see especially `docs/FULL_PROJECT_AUDIT.md`, `docs/03-ui-ux-spec.md`, `docs/todo-full-implementation.md`, `docs/07-roadmap.md`, `docs/macOS-installer-options.md`, and `README_REPLACEMENT.md` in that folder).

**Intended documentation source-of-truth order** (from audit — keep these mutually consistent after roadmap changes):

1. `README.md`
2. `docs/project-audit-and-feature-status.md`
3. `docs/07-roadmap.md`
4. `docs/todo-full-implementation.md` (this file)
5. `docs/03-ui-ux-spec.md`

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

- [x] **Stronger sectional navigation** for dense controls (audit + spec). *(Right column: “Authoring” horizontal chip row + scrollable content in [`SceneStudioView.swift`](../CosmicVisualizer/CosmicVisualizer/App/SceneStudioView.swift).)*
- [x] **Segmented or tabbed sub-mode** clarity for: **Scene · Look · Fractal · Liquid · Overlay · Palette** (audit recommends; spec recommended sub-sections). *(Persisted `SceneStudioAuthoringSection` chips + single visible section.)*
- [x] **Collapsible cards** with **persisted expansion state** for heavy sections (audit). *(`@AppStorage` for liquid pour vs palette subsections; overlay files vs overlay cards.)*
- [x] **Consolidation retained**: palette + overlay + fractal + liquid authoring in one surface (defensible; `scene_studio` rule: preview vs controls split).

---

## Section E — Controller (mapping / performance control)

- [x] **Mapping summary cards** — stronger visibility of MIDI/OSC mappings (audit). *(Overview: GroupBox cards for MIDI continuous, MIDI triggers, OSC examples in [`ControllerView.swift`](../CosmicVisualizer/CosmicVisualizer/App/ControllerView.swift).)*
- [x] **Filter / search** for fader groups / larger rigs (audit). *(Faders tab: search field filters DMX fixture groups by title or channel label.)*
- [x] **Planned / disabled** control labeling — unambiguous styling (audit). *(“Planned” capsule next to disabled DMX / combined learn modes.)*
- [x] **Visual separation** of: scene parameters vs DMX fixture controls vs learned controls (audit). *(Cyan-tinted “Scene parameters” vs orange-tinted fixture cards; fader captions label MIDI vs DMX manual.)*
- [x] Reduce **raw engineering** feel toward polished operator surface (ongoing). *(Copy + grouping refresh on Overview/Faders; further polish optional.)*

---

## Section F — Settings

- [x] **Basic / Advanced** disclosure (or equivalent) for **transport-heavy** blocks: DMX output, Art-Net/sACN, inbound DMX, RDM (audit). *(Persisted `settings.transportUITier` segmented control; Basic hides scaffold blurbs, live diagnostics, frame timing, and full RDM; Advanced shows them — [`SettingsView.swift`](../CosmicVisualizer/CosmicVisualizer/App/SettingsView.swift).)*
- [x] Consider **grouped panes or subpages** if Settings continues to grow (audit: optional). *(DMX area split into titled sub-blocks: output / inbound / RDM; nested GroupBoxes for diagnostics — further tabbing optional.)*
- [x] **Stronger transport diagnostic grouping** (audit “Missing UI” + Settings gaps). *(Advanced: separate GroupBoxes for output stream, inbound receiver, frame timing.)*
- [x] Broad coverage present: beta status, updates, feedback, show package archive, AI, remote, OSC, audio, DMX scaffolds (`SettingsView` / `AppModel`).

---

## Section G — Lighting workspace

- [x] **Sub-navigation** clarity for: **Patch · Cues · Stage · Verify · Tools** (audit + spec; may exceed current two-tab layout). *(Five `TabView` tabs with SF Symbols in [`LightingWorkspaceView.swift`](../CosmicVisualizer/CosmicVisualizer/Features/Lighting/LightingWorkspaceView.swift).)*
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

- [x] **Stronger confidence scoring** and diagnostics for verification (audit: in progress). *(`FixtureVerificationEvaluator.confidence01` / run average; per-fixture % + signal Δ in report; [`FixtureVerificationModels.swift`](../CosmicVisualizer/CosmicVisualizer/Features/Expansion/FixtureVerificationModels.swift).)*
- [x] **Final operator UX polish** in stage / verification flows (audit). *(Verify tab: exposure banner + intro; Stage plan: mid-tone exposure tip.)*
- [x] **Low-light / overexposure** scan guidance — baseline messaging done; continue refinement as needed. *(Extra **weak contrast** `exposureHint`; `fixtureVerificationExposureHint` banner on Verify; tests extended.)*

---

## Section I — Transport and DMX (network / desk / performance)

**Open — finish criteria**

- [x] **Multi-universe outbound** via **Art-Net** — one UDP packet per logical fixture universe; **network universe** in Settings is an **offset** added to each logical universe (clamped to protocol limits). `DMXUniverseBuilder.buildPerUniverse`, `AppModel.buildDMXUniversesForNetwork`, `ArtNetTransport.sendUniverseMap`, `DMXOutputService.tick` for `artnet`.
- [x] **Multi-universe outbound** via **sACN** — same wiring (`SACNTransport.sendUniverseMap`, `DMXOutputService` mode `sacn`).
- [ ] **Inbound DMX** “desk-grade” path — listener still decodes **one** Art-Net or sACN universe at a time; inbound merge applies to the **local build for universe 0** only (Settings copy + roadmap for multi-universe inbound). `DMXInputService` + merge + UI remain partial for large shows.
- [ ] **E1.31 / sACN** — verify full framing / priority / discovery expectations vs. a reference receiver in the field (implementation may still have gaps beyond happy-path multicast).
- [ ] **RDM discovery/probing** beyond **mock/scaffold** — replace or augment `RDMDiscoveryService` mock with real workflow when ready.
- [ ] **Performance profiling** under **larger fixture counts / high modulator density** — extend beyond current profiler + Settings diagnostics.

**Progress notes (keep in sync with code)**

- [x] Initial Art-Net/sACN **scaffolding**, UDP send path, packet builders — extended with **per-universe** send and **pkt/tick** in output diagnostics (`extendedDiagnostics` / Settings / Lighting patch strip).
- [x] Inbound listener **scaffold**, HTP/LPT merge, decode tests — partial; **single-universe** listener (see open criteria).
- [x] RDM **mock** probe + UI scaffold — partial.
- [x] DMX **runtime profiler** + over-budget frames — partial (`DMXPerformanceProfiler`, Settings).

---

## Section J — Control parity (native / web / MIDI / OSC)

- [x] **Systematic parity audit** — canonical path and surface notes: [`control-parity.md`](control-parity.md). OSC layer + cue/scene/tempo gaps closed (addresses in [`osc-control.md`](osc-control.md) + `OSCControlBusStub.parseCommand`).
- [x] OSC **state query** `/cosmic/state/get` aligned with web state JSON — `OSCControlService` + `AppModel.makeWebStateSnapshotData()`.
- [x] **Web / remote** live recording **start/stop/status** + **latest output path** in state — `RemoteControlCommand`, `WebControlStateDTO`, OSC `/cosmic/recording/*`.
- [ ] **Authenticated API relay** for **feedback issue submission** without storing personal tokens locally — `FeedbackAndLogsService` / Settings follow-up.

---

## Section K — Release, installer, signing, Sparkle

**Recommended beta path (audit + `macOS-installer-options.md` + [`release-runbook.md`](release-runbook.md))**

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

**From audit / audit-pack roadmap (“beta-ready”)**

Full implementation is in reach when:

1. [ ] **Docs / spec / roadmap / README** agree (no drift).
2. [ ] **Live** performance UX is clearly separated from **authoring** (hierarchy, meters, beat pulse, summary strip).
3. [ ] **Verification** is reliable, test-backed, and operator-polished where it matters.
4. [ ] **Transport** claims match behavior (scaffold honestly labeled; network paths production-stable where advertised).
5. [ ] **Beta tester** can install and run **without Xcode friction** (DMG path validated).
6. [ ] **OSC / web / MIDI** parity is **verified**, not assumed.

**Existing backlog criterion (implementation depth)**

1. [ ] P0/P1 stability and operator UX items above are done and validated (tests + runbooks where applicable).
2. [ ] P2 multi-universe / inbound / RDM / profiling items **ship** with documented setup and diagnostics.
3. [ ] Control parity (MIDI / web / OSC) reaches **documented** equivalent coverage.

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
