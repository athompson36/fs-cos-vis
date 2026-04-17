# TODO - Full Feature Implementation Backlog

Last updated: 2026-04-17

## Current status

- Core visualization, audio analysis, lighting patch/cue/modulation, stage layout, 2.5D preview, OFL import, and assisted fixture verification are implemented.
- Remaining items focus on scale, robustness, and advanced transport/control parity.

## Priority P0 (stability and correctness)

- [ ] Add deterministic tests for dual-camera fixture verification flow (primary + secondary fallback).
- [ ] Add regression tests for stage layout camera overlays and scan-angle persistence.
- [ ] Add coverage for stage object auto-scaling against stage dimensions and JSON migration.
- [ ] Harden fixture verification cancellation/resume behavior under camera disconnect/reconnect.

## Priority P1 (operator UX and throughput)

- [ ] Stage plot UX polish: snap-to-grid, duplicate object, lock object, layer ordering.
- [ ] Stage plot scan setup wizard: explicit “position cameras, then resume scan” guided steps.
- [ ] Verification report UX: jump-to-fixture correction actions and confidence severity filters.
- [ ] Improve scan messaging for low-light/overexposure conditions.

## Priority P2 (DMX expansion)

- [ ] Multi-universe transport support via Art-Net/sACN.
- [ ] Inbound DMX path for external desk integration.
- [ ] RDM discovery/probing roadmap implementation.
- [ ] Performance profiling for larger fixture counts and high modulator density.

## Priority P3 (integration parity)

- [ ] OSC control surface parity with existing web + MIDI controls.
- [ ] Export/import automation around full show packages and CI smoke validation.
- [ ] Additional fixture-source enrichment pipeline beyond OFL-first strategy.

## Completion criterion for “full implementation”

Treat full implementation as complete when:

1. P0 + P1 are done and validated by tests plus manual operator runbooks.
2. P2 multi-universe transport ships with documented setup and diagnostics.
3. Control parity (MIDI/web/OSC) reaches equivalent command coverage.
