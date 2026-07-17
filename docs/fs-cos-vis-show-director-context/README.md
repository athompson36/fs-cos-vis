# FS COS VIS — Show Director context pack (reference)

**Status:** Reference input pack. Live source-of-truth for implementation is:

1. Root `README.md`
2. `docs/project-audit-and-feature-status.md`
3. `docs/07-roadmap.md`
4. `docs/production-and-show-director-todo.md`
5. `docs/superpowers/specs/2026-07-16-show-director-foundation-design.md` (approved SD-M0–M3 contract)

Documents in this folder remain useful product/architecture background, but they are **not** competing live status docs. Where they conflict with the foundation design or production todo, prefer the live SoT chain above.

## Current Product Shape

The app should be treated as a mature SwiftUI/Metal beta rather than a greenfield DMX controller. Existing work covers cosmic visual rendering, audio analysis, MIDI/OSC/web control, DMX patching, fixture planning, Art-Net/sACN/OpenDMX output, external display output, Syphon, recording, project folders, and packaged show assets.

The Show Director foundation (models, validation, package store, pure reducer, actor engine, fake adapters) is implemented in-repo. Remaining work starts at real endpoint adapters (SD-M4) and Guided Setlist UI (SD-M5).

## Documentation in this pack

- `docs/01-cursor-context.md`
- `docs/project-audit-and-feature-status.md` (pack copy; live audit is at repo root `docs/`)
- `docs/show-director-product-spec.md`
- `docs/show-director-architecture.md`
- `docs/show-director-implementation-roadmap.md`
- `docs/show-director-integrations.md`
- `docs/show-control-json-examples.md`
- `docs/07-roadmap.md` (pack copy; live roadmap is at repo root `docs/07-roadmap.md`)
