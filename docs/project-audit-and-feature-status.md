# Project audit and feature status

**Last updated:** 2026-04-19  

Single-place summary of **what the product is today** and how documentation should talk about it. Align with [`07-roadmap.md`](07-roadmap.md), [`todo-full-implementation.md`](todo-full-implementation.md), and [`03-ui-ux-spec.md`](03-ui-ux-spec.md).

## Product positioning

- **Cosmic Visualizer** (repo: FS-COS-VIS) is a **late-stage beta** macOS application: hybrid **real-time visualization + live/show control**, not a Cursor starter template.
- **Intentional IA decision:** There is **no standalone “Palette Browser” or “Overlay Manager” screen**. Palette creation/selection and overlay authoring live in **Scene Studio** by design. Documentation must describe that consolidation, not treat those as missing features.

## Implemented — core visualization and UI

- Scene library, scene editing, scene cue strip, transitions  
- Fractal + liquid-light rendering, composite pass, palette/theme systems  
- **Live Show** and **Scene Studio** with scalable previews; performance vs authoring split (grouped action bands, audio meter, beat-phase ring, active summary strip — see [`todo-full-implementation.md`](todo-full-implementation.md) Section C)  
- External display routing and fullscreen presentation  
- **Syphon** integration: **vendored in-repo** at [`Vendor/Syphon-Framework`](../Vendor/Syphon-Framework) (full tree; not a git submodule) for `import Syphon` / Metal-OBS style paths  
- **Infinite zoom** motion modes (Standard, Infinite Tunnel, Event Horizon) with expanded zoom modulation  
- Overlay cards, import flows, black-background removal tooling (authoring-adjacent; some actions also reachable from Live Show)  

## Implemented — audio

- Input device enumeration and selection  
- **Input channel modes:** stereo pairs, mono, mix-all  
- FFT / RMS / peak / flux, BPM and beat-confidence feeds  
- Microphone permission: explicit request on audio start + **Open Microphone Settings** / retry flows (important after new installs/builds)  
- OBS / forwarding-oriented audio path documentation in Settings  

## Implemented — live output and capture

- **Live output recorder:** main preview or external output, quality presets (fps/bitrate), project-local `Media/Recordings` when a show folder is active  
- Share/reveal recording; health indicators for window availability and screen/microphone permissions  
- **Remote/OSS parity:** recorder start/stop, source, quality; status and latest path exposed via web `/api/state` and OSC (`/cosmic/recording/*`)  

## Implemented — control and integration

- Native **Controller** surface; tempo, learn, faders, DMX-oriented group controls  
- **HTTP + WebSocket** remote control; `WebControlStateDTO` / schema (includes **`dmxPerformance`** summary on `/api/state` and OSC `/cosmic/state/get`)  
- **MIDI** mapping store and device integration  
- **OSC** UDP listener (port, LAN bind, optional token), expanded command mapping (layer/tempo/lighting aligned with web/MIDI where applicable), `/cosmic/state/get` JSON snapshot aligned with web state — see [`control-parity.md`](control-parity.md) and [`osc-control.md`](osc-control.md)  
- Setup **wizard** (beta 0.1a): skippable steps, project/audio/output/DMX/AI, provider-specific AI API onboarding (e.g. OpenAI-compatible vs Anthropic)  
- Optional **analytics** for wizard completion/skip and exportable onboarding diagnostics  

## Implemented — lighting and DMX

- Fixture profiles/instances, patch document, conflict audit, persistence  
- Cues, crossfade, bookmark metadata for overlay text substitution; overlay element timeouts  
- Modulation runtime merged into DMX build  
- Stage layout, 2D editor, 2.5D preview, backdrop cues, gear objects, scan-camera overlays (primary + optional secondary / continuity-style path)  
- Fog/haze learn, emergency kill, cue envelopes  
- **OFL import** and **curated catalog** sync; **merged fallback fixture list** for offline coverage (`ofl_curated` vs `curated_local` catalog sources)  
- **Fixture verification** workflow, reports, scan wizard steps, severity filters, correction shortcuts  
- **JSON** import/export helpers in Lighting workspace (power user)  

## Implemented — network DMX (honest boundaries)

- **Art-Net** and **sACN outbound:** per-logical-universe UDP send (one packet per universe), **network universe offset** in Settings, output diagnostics (**pkt/tick**); same **UDP** behavior over **Ethernet or Wi‑Fi** on the LAN; see `DMXUniverseBuilder`, `AppModel.buildDMXUniversesForNetwork`, `DMXOutputService`, `ArtNetTransport` / `SACNTransport`  
- **Inbound** Art-Net/sACN: **multi-universe** contiguous range + HTP/LPT merge; **network** path merges per matching logical universe; **USB** merges the configured first universe into the single local buffer; **sACN** joins E1.31 multicast (`239.255.*.*`) per universe in range for IGMP/Wi‑Fi  
- **sACN / E1.31:** **outbound** full E1.31 data packets; **inbound** standard decode + legacy scaffold + **framing-priority merge** for competing sources; **extended** sync/discovery PDUs **counted** in diagnostics (no sync timing / discovery protocol); field validation vs reference receivers still recommended for your environment  
- **RDM** discovery: operator controls + **mock/deterministic** probe for workflow; **real RDM** stack TBD  
- **DMX performance profiler:** tick timings, **max build/send/total**, **nine-bucket** duration histogram (total), **approx. median / p95** for **total / build / send** (binned), **reset** of accumulators, over-budget frames, Settings diagnostics, plus **fixture / modulator / logical-universe** counts on the last tick (optional exact streaming quantiles: backlog)  

## Implemented — project packaging and ops

- Show **project folder** save/load (JSON documents + `Media/`, `Artifacts/`, `Backups/`)  
- **`.cosmicshow.zip`** archive export/import from Settings  
- **CI:** `show-package-smoke` workflow + `scripts/ci/smoke-show-package.sh`; full macOS unit tests — [`.github/workflows/unit-tests-macos.yml`](../.github/workflows/unit-tests-macos.yml)  
- **Beta updates** (Sparkle-oriented; **feed URL / keys** still operator setup — [`release-runbook.md`](release-runbook.md)), **feedback** bundles, optional **relay URL** submission (no GitHub PAT), or direct GitHub API with token  

## Documentation and audit alignment

- [`README.md`](../README.md) describes beta product, not “Cursor starter.”  
- Roadmap, backlog, and this file should stay consistent; large releases should update [`todo-full-implementation.md`](todo-full-implementation.md) open items.  
- **Shipping / production pass:** executable gates and checklists — [`production-readiness-checklist.md`](production-readiness-checklist.md).  
- The folder [`fs-cos-vis-audit-and-docs-update/`](fs-cos-vis-audit-and-docs-update/README_REPLACEMENT.md) is a **historical audit pack snapshot**; **live** source-of-truth order is listed at the top of [`todo-full-implementation.md`](todo-full-implementation.md).  

## Remaining gaps (see also backlog)

- **Production readiness:** executable gates and operator scripts — [`production-readiness-checklist.md`](production-readiness-checklist.md). Doc-sync and Gates **0–2** (+ transport certification write-up for Gate 3) are reflected in root `docs/`; **DMX lab sub-gates 3a–3e**, **signed/notarized release (Gate 5)**, and optional **feedback relay deploy (Gate 6)** remain open until run in your environment.  
- **Inbound DMX:** multi-universe listener + network per-universe merge shipped; **sACN** E1.31 **priority** merge shipped; further desk-grade polish still evolving ([`todo-full-implementation.md`](todo-full-implementation.md) Section I).  
- **sACN/E1.31:** confirm framing / sync / discovery vs field receivers where you need guarantees.  
- **RDM** beyond mock; **large-rig** DMX profiling beyond timing + rig-scale counts + histogram + **binned** median/p95 (exact streaming quantiles / per-subsystem optional).  
- **Feedback:** optional **HTTPS relay** in Settings (JSON POST; no GitHub PAT); hosted relay that calls GitHub remains deployer setup (Section J).  
- **Release:** Developer ID sign, notarize, DMG/ZIP to testers, Sparkle appcast + Info.plist keys — [`release-runbook.md`](release-runbook.md), Gate 5 worksheet [`distribution-checklist.md`](distribution-checklist.md).  
- **Verification:** optional deeper CV / geometry beyond current confidence and heuristics if product scope demands it.  
