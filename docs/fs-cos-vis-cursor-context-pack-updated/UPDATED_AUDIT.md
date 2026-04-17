# FS-COS-VIS Repo Scan Audit Update
Date: 2026-04-17

## Summary

This update reflects a fresh scan of the current `athompson36/fs-cos-vis` repository state.

The repo is no longer best described as a starter. It is a substantial hybrid macOS application that already includes:
- core fractal/liquid visualization
- audio analysis and BPM systems
- live scene performance surfaces
- web control
- MIDI mapping
- lighting patch/cue/modulation systems
- stage layout and 2.5D preview
- fixture verification workflows
- OFL fixture import support

## What changed from the earlier simplified context

The earlier context pack treated the project more like a visualizer that was expanding into show control.
The current repo state shows the opposite balance:

- the app is now a **hybrid visualizer + lighting/show-control platform**
- lighting, patching, stage planning, and verification are now first-class systems
- the remaining work is mostly:
  - spec alignment
  - operator UX polish
  - transport/control parity
  - test hardening
  - show-safe reliability

## Repo-verified status

### Already implemented
- scene management and scene editing
- fractal + liquid renderer pipeline
- composite pass and palette controls
- live show / scene studio / controller / settings / lighting workspace surfaces
- BPM and audio feature extraction
- input device and channel selection
- external display routing
- HTTP/WebSocket web control server
- MIDI mapping systems
- fixture patching, cues, modulation, haze kill
- stage layout with fixtures and gear objects
- stage camera overlays and verification support
- OFL fixture import and verification reporting

### Still clearly incomplete or still listed as backlog
- deterministic tests for dual-camera verification
- stage plot polish (snap, duplicate, lock, z-order)
- scan/verification UX hardening
- live recorder health/diagnostics
- multi-universe Art-Net / sACN
- inbound DMX
- RDM discovery/probing
- OSC parity
- full show package import/export automation and CI smoke validation

## Spec mismatches still worth tracking

The checked-in UI spec still names these as primary first-class screens:
- Theme / Palette Browser
- Overlay Manager

The current implementation appears to place those workflows inside Scene Studio rather than exposing them as dedicated primary screens.
That means one of two things must happen:
1. implementation grows into those dedicated screens, or
2. the spec is updated to document the consolidation intentionally

The same applies to the Performance View spec item:
- quick palette strip

It is still worth explicitly auditing whether the current live workflow satisfies that requirement in a strong, obvious way.

## Updated completion framing

Do not describe this repo as “incomplete basic app scaffolding.”
Describe it as:

**A late-stage hybrid visualizer + show-control application that still needs completion-level hardening, parity, and UX alignment.**

## Recommended next execution order

1. Audit and resolve spec mismatches:
   - palette browser
   - overlay manager
   - quick palette access in live workflow

2. Harden operator-critical flows:
   - verification determinism
   - stage plot polish
   - recorder diagnostics

3. Complete control/transport parity:
   - OSC
   - inbound DMX
   - multi-universe network DMX

4. Finish packaging and release-readiness:
   - show package automation
   - CI smoke tests
   - updated docs and runbooks

## Cursor guidance update

Cursor should now assume:
- this repo is mid-to-late phase
- new work should prefer refinement over invention
- duplicate subsystem creation is a major risk
- docs/spec drift is now one of the most important problems to prevent