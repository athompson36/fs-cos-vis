# Production readiness — execution checklist

**Purpose:** Single trackable artifact for the **one-pass** production plan: implement, verify, document, and ship what remains. Align with the canonical doc stack and close with a doc-sync PR.

**Canonical documentation order** (update these on close-out, in this order):

1. [`README.md`](../README.md)
2. [`project-audit-and-feature-status.md`](project-audit-and-feature-status.md)
3. [`07-roadmap.md`](07-roadmap.md)
4. [`todo-full-implementation.md`](todo-full-implementation.md)
5. [`03-ui-ux-spec.md`](03-ui-ux-spec.md)

**Supporting:** [`lighting-roadmap.md`](lighting-roadmap.md), [`control-parity.md`](control-parity.md), [`control-schema-coverage.md`](control-schema-coverage.md), [`control-plane-smoke.md`](control-plane-smoke.md), [`uat-checklist.md`](uat-checklist.md), [`ui-page-verification.md`](ui-page-verification.md), [`dmx-lab-procedures.md`](dmx-lab-procedures.md) (Gate 3a / 3b.2 / 3c.2), [`feature-surface-matrix.md`](feature-surface-matrix.md), [`historical-docs-reconciliation.md`](historical-docs-reconciliation.md), [`osc-control.md`](osc-control.md), [`release-runbook.md`](release-runbook.md), [`distribution-checklist.md`](distribution-checklist.md) (Gate 5), [`macOS-installer-options.md`](macOS-installer-options.md), [`beta-0.1a-release.md`](beta-0.1a-release.md).

**Workspace rules:** [`.cursor/rules/live_show.mdc`](../.cursor/rules/live_show.mdc), [`scene_studio.mdc`](../.cursor/rules/scene_studio.mdc), [`lighting_workspace.mdc`](../.cursor/rules/lighting_workspace.mdc). Module notes: [`FSDMXVision/AGENTS.md`](../FSDMXVision/AGENTS.md).

**Historical (do not treat as live requirements without reconciliation):** [`fs-cos-vis-audit-and-docs-update/`](fs-cos-vis-audit-and-docs-update/README_REPLACEMENT.md).

---

## Principles

- [x] **Single control spine:** Automation flows through `RemoteControlCommand` → `AppModel.applyRemoteCommand` (see [`control-parity.md`](control-parity.md)).
- [x] **Test-before-close:** Deterministic automation where possible; lab/field checklists for hardware-dependent behavior (DMX, multicast, receivers) — **Gate 1** (164 macOS unit tests + CI; verified green 2026-07-16), **Gate 4** [`uat-checklist.md`](uat-checklist.md); **Gate 3a**, **3b.2**, **3c.2** remain lab/field.
- [x] **Honest boundaries:** Scaffolds stay labeled; certification statements distinguish lab-proven vs best-effort vs future — see [`lighting-roadmap.md`](lighting-roadmap.md) § *Production readiness — transport certification* and Section I in [`todo-full-implementation.md`](todo-full-implementation.md).
- [ ] **One close-out doc PR** touching only the canonical list above — *optional consolidation when cutting a release; Gate 7 content was last synced 2026-04-19.*

---

## Gate 0 — Documentation & inventory freeze

| # | Task | Done |
|---|------|------|
| 0.1 | Reconcile `docs/fs-cos-vis-audit-and-docs-update/` vs root `docs/*`; list contradictions; fix or mark superseded | [x] — see [`historical-docs-reconciliation.md`](historical-docs-reconciliation.md) |
| 0.2 | Complete **feature × surface matrix** (see template below); file in repo or team wiki | [x] — [`feature-surface-matrix.md`](feature-surface-matrix.md) |
| 0.3 | Confirm **IA:** Palette Browser / Overlay Manager are **not** standalone screens (Scene Studio only) — matrix reflects N/A | [x] |

### Feature × surface matrix (template)

Copy to a spreadsheet; **rows** = areas from [`project-audit-and-feature-status.md`](project-audit-and-feature-status.md). **Columns:** Native UI | `POST /api/command` | MIDI | OSC | `GET /api/state` / WS | Unit tests | Manual UAT | Doc ref.

**Exit:** Matrix reviewed; no orphan requirements from historical audit pack.

---

## Gate 1 — Automated quality baseline

| # | Task | Done |
|---|------|------|
| 1.1 | `xcodebuild -scheme FSDMXVision -destination 'platform=macOS' test` — all tests green | [x] — 199 tests, 0 failures (2026-07-16 local after Show Director foundation; was 169 earlier same day, 164 before AI tests, 154 on 2026-04-19; see [`audit-execution-record.md`](audit-execution-record.md)) |
| 1.2 | CI: [`show-package-smoke.yml`](../.github/workflows/show-package-smoke.yml) + `scripts/ci/smoke-show-package.sh` green | [x] — verified local run (2026-04-19) |
| 1.3 | CI (optional): add workflow for full unit tests on macOS if cost allows — see [`todo-full-implementation.md`](todo-full-implementation.md) Section L | [x] — [`unit-tests-macos.yml`](../.github/workflows/unit-tests-macos.yml) |
| 1.4 | Release artifact: [`release-macos-beta.yml`](../.github/workflows/release-macos-beta.yml) + `scripts/release/package-beta.sh` produces DMG/ZIP (unsigned OK for internal); document signed vs unsigned per [`release-runbook.md`](release-runbook.md) | [x] — CI + local path documented (unsigned artifact until signing secrets; see runbook § Gate 1.4) |

**Exit:** “Green” definition = unit tests + show-package smoke + Release build path documented.

---

## Gate 2 — Control plane (HTTP / MIDI / OSC / WebSocket)

| # | Task | Done |
|---|------|------|
| 2.1 | Diff `ControlSchema.cosmicDefault()` vs `applyRemoteCommandOnMainThread` — table of command types; note schema gaps | [x] — [`control-schema-coverage.md`](control-schema-coverage.md) |
| 2.2 | OSC: validate [`osc-control.md`](osc-control.md) routes + `/cosmic/state/get` vs `WebControlStateDTO` — scripted smoke (`nc`/`socat`) or integration test | [x] — [`control-plane-smoke.md`](control-plane-smoke.md) § 2.2 + `scripts/osc/examples.sh` / `query-state.sh` |
| 2.3 | HTTP: `GET /api/state`, `POST /api/command`, WS — light load / error behavior documented or tested | [x] — [`control-plane-smoke.md`](control-plane-smoke.md) § 2.3 + [`scripts/ci/smoke-control-plane.sh`](../scripts/ci/smoke-control-plane.sh) |
| 2.4 | MIDI: regression on learn + `MIDIMappingStore` persistence (Controller UAT) | [x] — `MIDIMappingTests` + Controller steps in [`uat-checklist.md`](uat-checklist.md) |

**Primary code:** [`WebControlServer.swift`](../FSDMXVision/FSDMXVision/Features/Web/WebControlServer.swift), [`ControlSchema.swift`](../FSDMXVision/FSDMXVision/Features/Web/ControlSchema.swift), [`ControlBus.swift`](../FSDMXVision/FSDMXVision/Features/Expansion/ControlBus.swift), [`RemoteControlCommand.swift`](../FSDMXVision/FSDMXVision/Features/Control/RemoteControlCommand.swift), [`AppModel.swift`](../FSDMXVision/FSDMXVision/App/AppModel.swift).

**Exit:** Parity documented; settings-only exceptions explicit ([`control-parity.md`](control-parity.md)).

---

## Gate 3 — DMX transport & lighting (Section I)

Execute **in order**; each sub-gate has its own exit.

### 3a Outbound (regression)

| # | Task | Done |
|---|------|------|
| 3a.1 | Lab: Art-Net receiver — universe index + rate vs Settings **pkt/tick** / diagnostics | [ ] |
| 3a.2 | Lab: sACN receiver — same + confirm full E1.31 framing per [`lighting-roadmap.md`](lighting-roadmap.md) | [ ] |

**Anchors:** `DMXOutputService`, `ArtNetTransport`, `SACNTransport`, `AppModel.buildDMXUniversesForNetwork`.

### 3b Inbound merge

| # | Task | Done |
|---|------|------|
| 3b.1 | Unit coverage for HTP/LPT, multi-universe, USB vs network merge, **sACN priority** + staleness window | [x] — `DMXInboundMergeLogic` + `DMXInboundPacketDecoder` / priority tests in `DMXOutputServiceTests`; merge paths share one helper (`AppModel` USB + network) |
| 3b.2 | Field log (if console available): competing sources, priority behavior | [ ] |

**Anchors:** `DMXInputService`, `AppModel` inbound map + build methods.

### 3c sACN extended PDUs

| # | Task | Done |
|---|------|------|
| 3c.1 | **Decision:** Implement minimal sync/discovery handling **or** freeze behavior and ensure UI/docs say “counted / not timing” only | [x] — **Frozen:** extended PDUs counted in diagnostics only; no sync timing protocol — [`lighting-roadmap.md`](lighting-roadmap.md), Settings inbound diagnostics |
| 3c.2 | If field receivers emit extended PDUs — capture verification | [ ] |

### 3d RDM

| # | Task | Done |
|---|------|------|
| 3d.1 | **Decision:** Ship mock + roadmap **or** schedule real RDM integration (separate milestone) | [x] — mock + roadmap (Section I); real RDM TBD |
| 3d.2 | UI/docs match decision ([`todo-full-implementation.md`](todo-full-implementation.md) Section I) | [x] |

### 3e DMX profiler

| # | Task | Done |
|---|------|------|
| 3e.1 | Large-rig or trace-based load test — histogram + binned median/p95 sufficient **or** spec exact quantiles | [x] — binned + **exact** ring quantiles implemented and covered by `DMXOutputServiceTests` (`DMXPerformanceProfiler_*`); optional **large-rig** soak still field-only |
| 3e.2 | Settings copy matches implemented metrics | [x] — Settings **Diagnostics · Frame timing** strings match `DMXPerformanceProfiler` snapshot fields |

**Documentation exit (transport certification):** [x] — [`lighting-roadmap.md`](lighting-roadmap.md) § *Production readiness — transport certification*.

**Lab/field sub-gates still open:** **3a** (Art-Net/sACN receivers), **3b.2** (field log), **3c.2** (extended PDU field capture) — playbook: [`dmx-lab-procedures.md`](dmx-lab-procedures.md). Doc/decision/unit items **3b.1, 3c.1, 3d.*, 3e.*** are checked above.

---

## Gate 4 — Product UAT (scripted walks)

| Surface | Checklist | Rule / ref |
|---------|-----------|------------|
| Live Show | Audio meter, beat ring, Performance / Look / Capture groups, recorder, strips, overlay tools menu, no blocking inspectors | `live_show.mdc`, Section C |
| Scene Studio | Authoring chips, collapsible cards, palette+overlay consolidation | `scene_studio.mdc`, Section D |
| Controller | MIDI learn, fader search, mapping cards, OSC summary | Section E |
| Settings | Basic/Advanced transport tier, remote, OSC, audio, updates, feedback, show package | Section F |
| Lighting | Patch · Cues · Stage · Verify · Tools; JSON on Tools; DMX via `applyDMXPatchDocument` / cue APIs | `lighting_workspace.mdc`, Section G |

- [x] UAT script stored (Markdown or checklist tool) — [`uat-checklist.md`](uat-checklist.md)
- [x] **Process** for filing blockers (area labels + table) — [`uat-checklist.md`](uat-checklist.md)
- [ ] **Recorded blockers** from an executed UAT pass (fill the table when you run UAT; use `none` if clean) — *2026-04-19: sign-off row + placeholder blocker note added in [`uat-checklist.md`](uat-checklist.md); interactive Pass/Fail for each bullet still pending — see [`audit-execution-record.md`](audit-execution-record.md).*

---

## Gate 5 — Distribution & notarization (Section K)

**Maintainer worksheet:** [`distribution-checklist.md`](distribution-checklist.md) · **Workflows index:** [`.github/workflows/README.md`](../.github/workflows/README.md)

| # | Task | Done |
|---|------|------|
| 5.1 | Developer ID sign (nested frameworks/Syphon order per [`release-runbook.md`](release-runbook.md)) | [ ] |
| 5.2 | `notarytool` submit + **staple**; record submission ID | [ ] |
| 5.3 | DMG for testers; ZIP for Sparkle ([`macOS-installer-options.md`](macOS-installer-options.md)) | [ ] |
| 5.4 | Sparkle: `SUFeedURL`, `SUPublicEDKey`, hosted `appcast.xml`, test “Check for updates” on Release build | [ ] |
| 5.5 | Clean Mac without Xcode — [`beta-0.1a-release.md`](beta-0.1a-release.md) validation bullets | [ ] |

**Exit:** At least one **signed + notarized** artifact proven end-to-end.

---

## Gate 6 — Feedback relay (Section J) — optional

Skip if GitHub PAT in Settings is acceptable for your operators.

| # | Task | Done |
|---|------|------|
| 6.1 | Deploy HTTPS relay per [`scripts/feedback-relay/README.md`](../scripts/feedback-relay/README.md) | [ ] |
| 6.2 | Configure app relay URL + bearer; test issue submission | [ ] |
| 6.3 | Document operator URL and support escalation | [ ] |

**Exit (relay optional):** [x] **Deferred** for hosted relay — operators may use direct GitHub token, relay, or disable feedback; recorded under [`todo-full-implementation.md`](todo-full-implementation.md) Section J (Gate 6 paragraph). Rows 6.1–6.3 stay open until a relay is deployed.

---

## Gate 7 — Final documentation sync (mandatory)

Single PR updating:

- [x] [`project-audit-and-feature-status.md`](project-audit-and-feature-status.md) — “Remaining gaps” accurate (2026-04-19 sync)
- [x] [`07-roadmap.md`](07-roadmap.md) — In progress / Next (2026-04-19 sync)
- [x] [`todo-full-implementation.md`](todo-full-implementation.md) — open items only for real backlog (2026-04-19 sync)
- [x] [`lighting-roadmap.md`](lighting-roadmap.md) — remaining gaps + alignment with § *Production readiness — transport certification*
- [x] [`README.md`](../README.md) — short pointer to this checklist or “how we validated production readiness”
- [x] [`03-ui-ux-spec.md`](03-ui-ux-spec.md) — IA cross-reference to checklist / UAT (2026-04-19 sync)

**Exit:** No contradiction across README → audit → roadmap → todo. *(Last full pass: 2026-04-19.)*

---

## Suggested timeline (one team)

| Week | Gates |
|------|--------|
| 1 | 0, 1, 2 + start 3a–3b |
| 2 | 3c–3e + 4 |
| 3 | 5 (+ 6 if in scope) |
| 4 | Buffer, field fixes, **7** |

---

## Risk register

| Risk | Mitigation |
|------|------------|
| DMX/multicast/hardware behavior not fully CI-reproducible | Budget field/lab time; document “certified on X receivers” |
| Signing/notarization maintainer-only | Per [`release-runbook.md`](release-runbook.md); optional future CI secrets |
| Concurrency (UI + OSC + DMX) | Include combined stress in Gate 4 UAT |

---

## Next items (open gates)

Work in this order for a **named release** (everything above is either done or explicitly deferred):

1. **Gate 4 — UAT** — Walk [`uat-checklist.md`](uat-checklist.md); fill the **blockers** table (or write `none`). Combined stress: remote + OSC + DMX per risk register.
2. **Gate 5 — Distribution** — Follow [`distribution-checklist.md`](distribution-checklist.md): Developer ID sign → notarize + staple → DMG/ZIP → Sparkle/appcast → clean-Mac validation ([`beta-0.1a-release.md`](beta-0.1a-release.md)).
3. **Gate 3 (field)** — Complete manual/lab rows in [`dmx-lab-procedures.md`](dmx-lab-procedures.md) for **3a.1, 3a.2, 3b.2, 3c.2** when receivers and LAN are available (automated baseline already recorded there).
4. **Gate 6 (optional)** — Deploy feedback relay per [`scripts/feedback-relay/README.md`](../scripts/feedback-relay/README.md) **or** keep deferral in [`todo-full-implementation.md`](todo-full-implementation.md) Section J.
5. **Principle — one close-out doc PR** — When tagging a release, optionally squash updates to the **Canonical documentation order** list at the top of this file in a single PR.

---

## Quick code index (from backlog Appendix)

| Area | Entry points |
|------|----------------|
| Live Show | `LiveShowView.swift`, `LiveShowCueStripsView.swift` |
| Scene Studio | `SceneStudioView.swift`, `OverlayCardAuthoringView.swift` |
| Controller | `ControllerView.swift`, `MIDIMapping.swift` |
| Settings | `SettingsView.swift`, `RemoteControlSettings.swift` |
| Lighting | `LightingWorkspaceView.swift`, `AppModel.applyDMXPatchDocument` |
| Web | `WebControlServer.swift`, `WebControlStateDTO.swift`, `ControlSchema.swift` |
| OSC | `ControlBus.swift` |
| DMX | `DMXOutputService.swift`, `DMXInboundMergeLogic.swift`, DMX input patterns in `AppModel` |
| Show package | `ProjectStack.swift`, `ShowProjectPackage`, `AppModel` save/load |
| Release | `scripts/release/package-beta.sh`, `.github/workflows/release-macos-beta.yml` |

---

**Last updated:** 2026-04-19 (Gate 1.1 test count + [`audit-execution-record.md`](audit-execution-record.md))
