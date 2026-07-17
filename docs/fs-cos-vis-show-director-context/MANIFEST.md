# FS COS VIS Show Director Context Package

This ZIP recreates the documentation and Cursor context for the Unified Show Director roadmap for `athompson36/fs-cos-vis`.

## Intended Use

Unzip this package into a checkout of `fs-cos-vis` or provide it to Cursor as project context. The files define the product direction, architecture, integration constraints, endpoint schema examples, implementation sequence, and Cursor rules for extending the existing macOS SwiftUI/Metal DMX and visualization app into a unified show-control platform.

## Contents

- `README.md` - Project orientation updated around Unified Show Director.
- `docs/01-cursor-context.md` - High-signal Cursor briefing for the current codebase and next work.
- `docs/07-roadmap.md` - Product and engineering roadmap.
- `docs/project-audit-and-feature-status.md` - Audit summary and current development status.
- `docs/show-director-product-spec.md` - Product requirements for DJ, FOH, setlist, remote, lighting, video, overlay, and recording control.
- `docs/show-director-architecture.md` - Core model, reducer, engine, adapter, persistence, and runtime architecture.
- `docs/show-director-implementation-roadmap.md` - Ordered implementation milestones and acceptance criteria.
- `docs/show-director-integrations.md` - Traktor, Maschine, OBS, QLC+/DMX, video, remote, audio routing, and external protocol notes.
- `docs/show-control-json-examples.md` - Example JSON structures for show packages, cue actions, remote commands, and execution logs.
- `.cursor/rules.md` - General Cursor rules for this repository.
- `.cursor/rules/show_director.mdc` - Cursor rule focused on Unified Show Director implementation.

## Important Implementation Principle

Do not replace the existing visualization, lighting, patching, recording, protocol, or rendering systems. Add a typed show-control layer above them:

1. Codable show metadata models.
2. A deterministic reducer with no endpoint I/O.
3. An actor-isolated execution engine.
4. Endpoint adapters for existing app subsystems.
5. Guided setlist and DJ metadata control surfaces.
6. Remote command protocol for phone, watch, MIDI, OSC, and web clients.
