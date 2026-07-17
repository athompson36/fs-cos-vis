# Roadmap

## Status snapshot (2026-04-19)

High-level status. Keep aligned with [`project-audit-and-feature-status.md`](project-audit-and-feature-status.md), [`todo-full-implementation.md`](todo-full-implementation.md), and [`03-ui-ux-spec.md`](03-ui-ux-spec.md). Installer choices: [`macOS-installer-options.md`](macOS-installer-options.md).

## Completed foundation

- Audio input picker, live analysis metrics, FFT/BPM feeds
- Fractal + liquid render stack with compositing and palette controls
  - Extended fractal zoom motion modes (Standard / Infinite Tunnel / Event Horizon) with higher modulation range
- Live and studio control surfaces with external display routing
  - Live output recorder with source picker, project-folder recording destination, and share/reveal flow
  - First-run setup wizard with skippable steps (project/audio/output/DMX/AI)
  - Beta update and operator feedback/reporting controls in Settings
- Scene persistence, overlays, transitions, and performance workflow refinements
- **Live Show performance UX:** grouped action bands (Performance / Look / Capture), audio RMS/peak meter, beat-phase ring, **Active** summary strip, overlay file tools in menu — see [`todo-full-implementation.md`](todo-full-implementation.md) Section C
- **Scene Studio** persisted sectional chips (Scene · Look · Fractal · Liquid · Overlay · Palette) and collapsible cards
- **Settings** Basic/Advanced transport tier for DMX blocks
- MIDI mapping baseline and remote/web control API foundation
- **Control parity documentation:** [`control-parity.md`](control-parity.md); expanded **OSC** routes for layer/tempo/scene/lighting (`ControlBus.swift`); web `POST /api/command` remains the broadest command surface
- **Show package** `.cosmicshow.zip` import/export in Settings; CI smoke workflow for package roundtrip (`show-package-smoke`)
- **Network DMX outbound:** Art-Net/sACN **multi-universe** send (per logical universe + offset), diagnostics — see [`todo-full-implementation.md`](todo-full-implementation.md) Section I
- **DMX over Wi‑Fi / LAN:** Art-Net and sACN use **UDP** on the local network (same behavior on Wi‑Fi or Ethernet); **inbound sACN** joins E1.31 multicast groups per listened universe (`IP_ADD_MEMBERSHIP`) for IGMP-friendly reception — see Section I
- DMX/lighting vertical slice:
  - fixture library and patching
  - cues and crossfades
  - cue bookmark metadata for dynamic song/artist overlay values
  - modulation runtime
  - stage layout + 2.5D preview
  - fog/haze learn and safety controls
  - OFL import and enriched catalog (OFL sync + bundled curated fallback)
  - fixture verification (assisted camera workflow); deterministic tests for dual-camera and stage-camera overlays; scan setup wizard and report UX improvements
  - overlay element timeout auto-hide and metadata-bound text rendering
- **Syphon** vendored in-repo ([`Vendor/Syphon-Framework`](../Vendor/Syphon-Framework)) for screen/texture sharing
- **Production readiness (documentation + automation hooks):** [`production-readiness-checklist.md`](production-readiness-checklist.md), [`uat-checklist.md`](uat-checklist.md), [`control-plane-smoke.md`](control-plane-smoke.md), transport certification in [`lighting-roadmap.md`](lighting-roadmap.md); CI — [`unit-tests-macos.yml`](../.github/workflows/unit-tests-macos.yml) + [`show-package-smoke.yml`](../.github/workflows/show-package-smoke.yml)
- **Unified Show Director foundation (SD-M0–M3):** typed show graph, validation/migration, `show-director/` package persistence under existing `Media/`, pure reducer, actor engine with fake adapters and execution JSONL — design [`superpowers/specs/2026-07-16-show-director-foundation-design.md`](superpowers/specs/2026-07-16-show-director-foundation-design.md); tracking [`production-and-show-director-todo.md`](production-and-show-director-todo.md)

## In progress

- Show Director **real endpoint adapters** (SD-M4) and Guided Setlist UI (SD-M5)
- Fixture verification **quality** pass: optional deeper CV / geometry beyond current confidence where scope requires it
- Stage plot UX: ongoing polish (camera guidance, editing, scan/correction loops)
- **Authoring consolidation (documented):** Palette Browser and Overlay Manager are **not** separate app screens — they live in **Scene Studio**; Live Show includes quick palette access
- Network DMX: **inbound** multi-universe listener + per-universe merge (network); **RDM** beyond mock; **sACN** framing **priority** merge shipped; extended **sync/discovery** PDUs recognized + counted (no full protocol handling); field hardening where needed
- Capture/recording hardening, Sparkle publication, **signed/notarized** pipeline proof on real artifacts ([`release-runbook.md`](release-runbook.md))
- Optional: navigation model spike (sidebar vs TabView) — see [`03-ui-ux-spec.md`](03-ui-ux-spec.md)

## Next up (backlog)

- Inbound DMX + RDM: desk-grade merge **refinement** (beyond sACN priority + HTP/LPT) and mock RDM → real when ready ([`todo-full-implementation.md`](todo-full-implementation.md) Section I)
- Performance profiling under **large** rigs (timing + rig-scale counts + total-time **histogram** + **approx. median/p95** for total/build/send in Settings; optional exact streaming quantiles)
- **Feedback:** optional HTTPS **relay** in Settings for issue submission without a **GitHub** PAT; hosted relay still required for end-to-end automation (Section J)
- Cross-platform feasibility (Windows) — spike only

## Notes

- DMX stack: USB/OpenDMX + simulation + **network outbound multi-universe**; **label inbound/RDM scaffolds honestly** in UI and docs.
- Full “console parity” workflows still depend on **inbound** and **RDM** maturity, not outbound universe count alone.
- **Usability phases** (source clarity, remote parity, power-user efficiency, lab DMX): [`ux-roadmap.md`](ux-roadmap.md).
