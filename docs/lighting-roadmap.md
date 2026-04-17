# Lighting roadmap (implementation notes)

This document captures current implementation status, boundaries, and next work for the DMX lighting stack.

## Status (2026-04-17)

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

## In progress

- Verification fidelity improvements:
  - stronger confidence/diagnostic outputs
  - deeper camera calibration guidance
- Stage plot workflow polish for scan setup and correction loops

## Next milestones

1. **Transport expansion**
   - Art-Net/sACN multi-universe output
   - inbound DMX and RDM discovery roadmap
2. **Verification depth**
   - richer CV/geometric fixture localization beyond luma-only checks
   - orientation/layout validation confidence metrics
3. **Console-scale workflow**
   - advanced chaser/sequence graphs
   - higher-density fixture/scene authoring ergonomics

## Non-goals (current shipping scope)

- GrandMA2/full-console parity
- Full trigger/envelope graph editor UI
- Production-grade incoming DMX + RDM stack (deferred to transport milestones)

## Persistence paths (Application Support `CosmicVisualizer/`)

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
