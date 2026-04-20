# Product UAT — scripted walkthrough (Gate 4)

**Next (shipping order):** After this pass, continue with **Gate 5** and any open field gates — see [`production-readiness-checklist.md`](production-readiness-checklist.md) § **Next items (open gates)**.

**Purpose:** Repeatable manual checks per surface, aligned with [`production-readiness-checklist.md`](production-readiness-checklist.md) Gate 4 and workspace rules ([`live_show.mdc`](../.cursor/rules/live_show.mdc), [`scene_studio.mdc`](../.cursor/rules/scene_studio.mdc), [`lighting_workspace.mdc`](../.cursor/rules/lighting_workspace.mdc)).

**How to use:** Work top to bottom; check each bullet or note **Pass / Fail / N/A** and file blockers with an area label (e.g. `live-show`, `lighting`).

**Companion automation:** [`control-plane-smoke.md`](control-plane-smoke.md) (HTTP/OSC/WS), [`scripts/ci/smoke-show-package.sh`](../scripts/ci/smoke-show-package.sh) (show package CI smoke).

---

## Live Show

- [ ] **Audio:** Input device + channel mode; **input meter** responds to signal; no silent failure without an obvious affordance.
- [ ] **Tempo:** BPM readout plausible; **beat-phase ring** animates with transport; tap tempo usable.
- [ ] **Performance / Look / Capture** groupings: scene prev/next/random; fullscreen; **active** summary strip shows scene / palette / cue context.
- [ ] **Recorder:** start/stop; file lands where expected; reveal in Finder works.
- [ ] **Cue strips** (when enabled): scene + lighting/backdrop strips behave; no layout blocking the Metal preview.
- [ ] **Overlay tools** live behind menu/disclosure — heavy authoring tools do not cover the preview.
- [ ] **Haze emergency** path works and is discoverable.

---

## Scene Studio

- [ ] **Authoring chips** switch Scene · Look · Fractal · Liquid · Overlay · Palette without losing context.
- [ ] **Collapsible cards** remember expansion; dense sections remain scrollable.
- [ ] **Palette / overlay** authoring lives here (no expectation of standalone Palette Browser / Overlay Manager apps).

---

## Controller

- [ ] **MIDI learn:** assign at least one discrete CC to **Next scene** (or another command); mapping appears in UI.
- [ ] **Persistence:** quit app and relaunch — mapping still applied (`MIDIMappingStore`). Automated coverage: `FSDMXVisionTests/MIDIMappingTests` (JSON encode/decode, continuous CC).
- [ ] **Fader search / mapping cards** usable for continuous parameters.
- [ ] **OSC summary** matches Settings (port, bind LAN, token if used); spot-check with [`osc-control.md`](osc-control.md).

---

## Settings

- [ ] **Basic / Advanced** tiers: remote HTTP port, auth token, bind LAN; OSC port + token; audio devices.
- [ ] **Updates / feedback** paths visible; understand relay vs direct token per [`todo-full-implementation.md`](todo-full-implementation.md) Section J.
- [ ] **Show package** import/export or project folder workflow exercised once per release candidate.

---

## Lighting workspace

- [ ] Navigate **Patch · Cues · Stage · Verify · Tools**; no dead-end navigation.
- [ ] **Tools** JSON import/export or patch/cue documents as your workflow requires (`AppModel.applyDMXPatchDocument` / cue APIs).
- [ ] **DMX transport** settings (universe offset, pkt/tick, diagnostics) readable; note any lab-only behavior per [`lighting-roadmap.md`](lighting-roadmap.md).

---

## Gate 2.4 — MIDI (cross-reference)

Satisfies the **persistence** slice of production Gate **2.4** together with **Controller** steps above. **Learn UI** remains manual here; automated tests do not cover `MIDIMappingStore` file I/O end-to-end.

---

## Sign-off

| Build | Date | Tester |
|-------|------|--------|
| Release `FSDMXVision.app` (DerivedData) + `dist/FSDMXVision-audit-2026-04-19.{dmg,zip}` | 2026-04-19 | Automation (full interactive pass still required) |

**Blockers:** File each issue with an **area** label (`live-show`, `scene-studio`, `controller`, `settings`, `lighting`, `web`, `dmx`, `release`) and link it here.

| ID | Area | Summary |
|----|------|---------|
| — | — | **None** — checklist bullets above were not individually Pass/Fail tested in the 2026-04-19 automation run; execute manually and replace this row with real issues or confirm `none` after a full walk. |

*(Until blockers exist, leave the table empty or remove rows.)*
