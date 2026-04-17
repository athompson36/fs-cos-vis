# TODO - Full Feature Implementation Backlog

Last updated: 2026-04-17

## Current status

- Core visualization, audio analysis, lighting patch/cue/modulation, stage layout, 2.5D preview, OFL import, and assisted fixture verification are implemented.
- Remaining items focus on scale, robustness, and advanced transport/control parity.

## Priority P0 (stability and correctness)

- [x] Add deterministic tests for dual-camera fixture verification flow (primary + secondary fallback).
- [x] Add regression tests for stage layout camera overlays and scan-angle persistence.
- [x] Add coverage for stage object auto-scaling against stage dimensions and JSON migration.
- [x] Harden fixture verification cancellation/resume behavior under camera disconnect/reconnect.
- [x] Add integration test for live overlay metadata substitution + timeout behavior during cue transitions.

## Priority P1 (operator UX and throughput)

- [x] Stage plot UX polish: snap-to-grid, duplicate object, lock object, layer ordering.
- [x] Stage plot scan setup wizard: explicit “position cameras, then resume scan” guided steps.
- [x] Verification report UX: jump-to-fixture correction actions and confidence severity filters.
- [x] Improve scan messaging for low-light/overexposure conditions.
- [x] Add recording quality controls (fps/bitrate presets) and explicit audio-source diagnostics in Live Show recorder UI.
- [x] Add recorder health indicators for external-output availability and screen/audio permissions.
- [x] Add setup wizard step analytics (completion/skip rates) and exportable onboarding diagnostics.
- [x] Resolve Palette Browser spec mismatch (dedicated surface vs intentional Scene Studio consolidation).
- [x] Resolve Overlay Manager spec mismatch (dedicated surface vs intentional Scene Studio consolidation).
- [x] Audit/implement quick palette access parity in Live Show workflow.

## Priority P2 (DMX expansion)

- [ ] Multi-universe transport support via Art-Net/sACN.
  - Added initial transport-mode scaffolding (`artnet` / `sacn`) with settings fields, universe targeting, frame diagnostics, and packet-framing placeholders in the DMX service.
  - Implemented UDP output send path (Art-Net port `6454`, sACN port `5568`) plus mode-specific serial-path gating and packet-builder test coverage.
- [ ] Inbound DMX path for external desk integration.
  - Added inbound listener scaffold with selectable Art-Net/sACN mode, universe filter, HTP/LPT merge policy, and live intake diagnostics in Settings.
  - Added inbound packet decode tests for Art-Net/sACN framing compatibility with current packet builders.
- [ ] RDM discovery/probing roadmap implementation.
  - Added operator-facing RDM scaffold controls (transport mode + universe + probe trigger) and status reporting in Settings.
  - Added deterministic mock probe service/result model plus focused unit coverage for discovery output shape.
- [ ] Performance profiling for larger fixture counts and high modulator density.
  - Added DMX runtime performance profiling (build/send/total tick timings, max tick, over-budget frame count) surfaced in Settings diagnostics.
  - Added deterministic unit coverage for profiler aggregation math and budget-threshold tracking.

## Priority P3 (integration parity)

- [ ] OSC control surface parity with existing web + MIDI controls.
  - Added OSC UDP listener settings (port/LAN/token) and runtime status diagnostics.
  - Added OSC address-to-command mappings for core scene/tempo/look controls and parser unit coverage.
  - Expanded OSC mappings to include manual BPM, liquid enable, scene jump by UUID, palette select by UUID, and lighting cue index selection.
  - Added OSC state query path (`/cosmic/state/get`) returning the same JSON snapshot used by web control state.
- [x] Export/import automation around full show packages and CI smoke validation.
  - Added project-package archive automation (`.cosmicshow.zip`) with import/export actions in Settings.
  - Added CI smoke workflow (`show-package-smoke`) running package roundtrip and archive import/export tests.
- [x] Additional fixture-source enrichment pipeline beyond OFL-first strategy.
  - Added merged fixture catalog pipeline combining OFL curated sync results with bundled curated fallback fixtures.
  - Added source tagging (`ofl_curated` / `curated_local`) and backward-compatible cache decode for older catalogs.
- [x] Add web/remote command parity for live recording start/stop/status and latest output path.
  - Added remote/web command handlers for live recorder start/stop plus source and quality preset selection.
  - Added OSC mappings for recording start/stop/source/quality and exposed recorder status/latest output path in `/api/state`.
- [ ] Add authenticated API relay option for feedback issue submission without storing personal tokens locally.

## Completion criterion for “full implementation”

Treat full implementation as complete when:

1. P0 + P1 are done and validated by tests plus manual operator runbooks.
2. P2 multi-universe transport ships with documented setup and diagnostics.
3. Control parity (MIDI/web/OSC) reaches equivalent command coverage.
