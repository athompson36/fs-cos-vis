# Lighting roadmap (implementation notes)

This document captures current implementation status, boundaries, and next work for the DMX lighting stack.

## Status (2026-04-19)

## Completed

1. **Fixture model and USB universe**
   - Profiles/instances, patch document, conflict auditing, migration compatibility
   - `DMXUniverseBuilder` integration of patch + cues + modulation
2. **Cues**
   - `LightingCueDocument`, active cue management, linear crossfade via target cue fade time
   - Cue editing/import/export and live-strip operations
   - Bookmark-scoped metadata map for dynamic live overlay text substitution
3. **Modulation**
   - `ModulationRuntime` routes LFO/tempo/audio-band offsets and applies merged per-channel output
4. **Stage and preview**
   - 2D stage placement editor with backdrop import and persisted layout
   - 2.5D preview driven from the same built DMX universe
   - Overlay card runtime now supports cue-metadata text binding and per-element timeout gating
5. **Live output capture + project persistence**
   - Live Show can record main preview or external output to project-local `Media/Recordings`
   - Post-record sharing/reveal is integrated in live controls
   - Project save now writes config snapshots and rolling backups under project-local folders
6. **Fog/haze**
   - Camera-assisted learn presets, cue envelope support, emergency kill/resume handling
7. **Verification and planning**
   - Assisted fixture verification runs with persisted JSON report
   - Stage-plot scan camera overlays (primary + optional secondary angled camera)
8. **Fixture source and import**
   - OFL import service and curated catalog sync with fog/haze-focused indexing
   - merged enrichment pipeline now combines OFL curated sync with bundled curated fallback fixtures for offline/missing-entry coverage
9. **Network outbound Art-Net / sACN (multi-universe)**
   - `DMXUniverseBuilder.buildPerUniverse` / `AppModel.buildDMXUniversesForNetwork`; `DMXOutputService` sends one UDP packet per logical universe; **network universe offset** in Settings; pkt/tick diagnostics
   - **Wi‑Fi / LAN:** same UDP transports on wireless or wired; inbound **sACN** joins E1.31 multicast per universe for IGMP (see `SACNMulticastAddress` / `DMXInputService` in `DMXOutputService.swift`)
   - **Inbound merge** (HTP/LPT, sACN **priority**, 3 s staleness): shared pure logic in `DMXInboundMergeLogic.swift` (`AppModel`); unit tests in `DMXOutputServiceTests` (`testDMXInboundMergeLogic_*`).
   - See also [`todo-full-implementation.md`](todo-full-implementation.md) Section I

## In progress

- Verification fidelity improvements:
  - stronger confidence/diagnostic outputs
  - deeper camera calibration guidance
  - mid-scan camera disconnect handling with resume guidance and partial-progress persistence
  - verification report severity filters and quick correction actions (select fixture profile, add default stage placement)
  - low-light / overexposure scan hints during per-fixture verification progress
- Stage plot workflow polish for scan setup and correction loops
  - added explicit scan setup wizard steps in fixture verification workflow (position cameras, then resume)

## Next milestones

1. **Transport — inbound and production hardening** (keep UI/docs honest)
   - **Outbound multi-universe:** shipped (see Completed above)
   - **Inbound:** contiguous **multi-universe** listener + HTP/LPT merge per logical universe on network output; USB merges the configured **first** universe into the single local buffer; **sACN** framing **priority** respected for competing sources (fresh buffer); full desk parity vs large consoles still **TBD**
   - **sACN/E1.31:** outbound full **E1.31** framing shipped; inbound priority merge shipped; extended **sync/discovery** PDUs counted in diagnostics; full sync timing / discovery protocol still optional / field-driven
   - **RDM:** operator mock workflow; **real RDM** stack TBD
2. **Performance profiling**
   - DMX runtime profiler records build/send/total frame timing, **max build/send/total**, a **fixed-bucket total-time histogram**, max frame duration, and over-budget frame counts
   - Settings **Frame timing** diagnostics include **fixture instance count**, **modulator count**, and **logical output universe count** (last tick) alongside timing, plus **approx. median / p95** for **total**, **build**, and **send** (binned) — extend further if you need exact streaming quantiles before claiming “console scale”
3. **Verification depth**
   - richer CV/geometric fixture localization beyond luma-only checks
   - orientation/layout validation confidence metrics
4. **Console-scale workflow**
   - advanced chaser/sequence graphs
   - higher-density fixture/scene authoring ergonomics
   - OSC / web / MIDI: documented in [`control-parity.md`](control-parity.md); [`osc-control.md`](osc-control.md)

## Non-goals (current shipping scope)

- GrandMA2/full-console parity
- Full trigger/envelope graph editor UI
- Production-grade **incoming** DMX + **real** RDM stack (tracked as milestones above)

## Production readiness — transport certification

Statements for [`production-readiness-checklist.md`](production-readiness-checklist.md) Gate 3 exit and honest operator expectations:

| Area | Status | Notes |
|------|--------|--------|
| **Outbound** Art-Net / sACN (multi-universe, offset, pkt/tick diagnostics) | **Shipped — lab/field validation operator-dependent** | Confirm with your receivers (universe index, rate) in Gate 3a |
| **Inbound** merge (HTP/LPT, multi-universe listen, USB vs network, **sACN priority** + staleness) | **Shipped — desk-grade parity vs large consoles TBD** | See Section I / tests in-repo; field log still valuable (3b) |
| **sACN** extended sync/discovery PDUs | **Best-effort / diagnostic** | Counted in UI; full sync timing / discovery protocol not certified |
| **RDM** | **Mock (USB) + real ArtPoll (network)** | Hardware/USB path is a deterministic mock; Art-Net/sACN modes run a real ArtPoll node discovery (not RDM GET/SET). Real RDM integration is a separate milestone |
| **DMX frame profiler** (histogram, binned median/p95, fixture/modulator/universe counts) | **Shipped** | “Console scale” claims still require large-rig or trace evidence (3e) |

## Persistence paths (Application Support `FSDMXVision/`; legacy installs may still have `CosmicVisualizer/` until migration runs)

| File | Content |
|------|-----------|
| `dmx_patch.json` | Profiles + instances + legacy toggle |
| `lighting_cues.json` | Cues + active index + bookmark metadata map (`cue-id -> key/value`) |
| `modulation.json` | Modulator definitions |
| `stage_layout.json` | Placements, backdrop, dimensions, stage objects, scan-camera overlays |
| `context/calibration.json` | Calibration sweep artifact |
| `context/fixture_verification.json` | Fixture verification report |
| `Media/Recordings/*.mov` | Live output recordings (project-local when project folder active) |
| `Artifacts/config_snapshot.json` | Captured project/runtime config snapshot on save |
| `Backups/backup-*/...` | Rolling backups of core project JSON documents |
| `Stage/*.png` (etc.) | Imported stage backdrop copies |
