# Audit and end-to-end verification record

**Run date:** 2026-04-19  
**Purpose:** Execution log for the plan in [`.cursor/plans`](../.cursor/plans) (full audit + E2E verification layers).

## Part A — Documentation and feature audit

| Source | Result |
|--------|--------|
| [`project-audit-and-feature-status.md`](project-audit-and-feature-status.md) | Consistent with roadmap/backlog; remaining gaps correctly call out Gates 3 field, 5 signing, optional relay. |
| [`07-roadmap.md`](07-roadmap.md) | Aligns with audit; in-progress items (fixture verification polish, Sparkle/signing proof) still accurate. |
| [`todo-full-implementation.md`](todo-full-implementation.md) | Section A and canonical order match; no stale “missing Palette Browser” claims. |
| [`03-ui-ux-spec.md`](03-ui-ux-spec.md) | IA consolidation (Scene Studio) matches code and audit docs. |
| [`control-schema-coverage.md`](control-schema-coverage.md) | Intentional schema subset documented; `SetLiquidReconstituteBPMSync` called out as implemented but not in bundled `ControlSchema`. |

**Contradictions found:** None.

## Part B — Automated quality baseline (Gate 1)

| Check | Result |
|-------|--------|
| Full macOS unit tests | **164** tests, **0** failures — `xcodebuild -scheme FSDMXVision -destination 'platform=macOS' test` (re-verified 2026-07-16; was 154 on 2026-04-19) |
| Show-package CI parity | **2** tests — `ShowProjectAndContextTests/testShowProjectPackageRoundTrip`, `testShowProjectArchiveExportImportRoundTrip` (did not run `smoke-show-package.sh` to avoid overwriting `project.local.yml`) |

## Part C — Control plane smoke (Gates 2.2–2.3)

**Status:** Not completed in this automation environment.

`open FSDMXVision.app` did not leave a running process (`pgrep FSDMXVision` empty); no TCP listener on `127.0.0.1:8765`. Typical causes: no interactive Aqua session (SSH/CI/agent host), or policy blocking GUI launch. UserDefaults precondition (`remoteControlEnabled` + `oscControlEnabled`) was written and restored from backup afterward.

**Operator follow-up (on a normal macOS desktop session):**

1. Enable **Remote control** and **OSC** in Settings (or inject settings JSON into `FSDMXVision.RemoteControlSettings.v1` before launch).
2. `bash scripts/ci/smoke-control-plane.sh`
3. `bash scripts/osc/examples.sh` (or `scripts/osc/query-state.sh`)

See [`control-plane-smoke.md`](control-plane-smoke.md).

## Part D — Packaging (unsigned release path)

| Artifact | Notes |
|----------|--------|
| `dist/FSDMXVision-audit-2026-04-19.zip` | From `scripts/release/package-beta.sh` |
| `dist/FSDMXVision-audit-2026-04-19.dmg` | UDZO |
| Signing | **Ad hoc / local** (`Sign to Run Locally`); not Developer ID / not notarized |

`COSMIC_RELEASE_APP` pointed at DerivedData Release:  
`…/DerivedData/FSDMXVision-…/Build/Products/Release/FSDMXVision.app`.

## Part E — Product UAT (Gate 4)

Interactive checklist in [`uat-checklist.md`](uat-checklist.md) was **not** executed step-by-step in this run (requires operator, audio, MIDI hardware as applicable). Sign-off table in that file updated with build label and a pointer here.

## Part F — DMX lab / field (Gates 3a, 3b.2, 3c.2)

**N/A** — no Art-Net/sACN receivers or field consoles in scope for this run. Follow [`dmx-lab-procedures.md`](dmx-lab-procedures.md) when lab gear is available.

## Part G — Distribution signing / notarization (Gate 5)

**N/A** — Developer ID signing and `notarytool` not run (no maintainer secrets / clean-Mac install in this pass). See [`distribution-checklist.md`](distribution-checklist.md).

---

**UserDefaults:** Before any defaults experiments, a domain export was saved to `/tmp/fsdmx_defaults_backup.plist` and re-imported at the end of the session.
