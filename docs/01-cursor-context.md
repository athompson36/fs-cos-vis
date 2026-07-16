# Detailed Cursor Context

**Last updated:** 2026-07-16

## Product state

FS DMX Vision is a **late-stage native macOS beta**, not a starter scaffold and not a Phase 1 MVP. Existing implementation includes:

- SwiftUI operator surfaces
- Metal fractal, liquid-light, and composite rendering
- audio input selection, FFT features, BPM, beat phase, tap tempo, and MIDI clock
- scene, palette, overlay, transition, and external-display workflows
- lighting patch, cue, modulation, stage, verification, USB/OpenDMX, Art-Net, and sACN systems
- local HTTP/WebSocket, OSC, and MIDI control
- Syphon output and live output recording
- project folders and `.cosmicshow.zip` packages
- setup, release, feedback, and production-readiness infrastructure

Read [`project-audit-and-feature-status.md`](project-audit-and-feature-status.md) before making claims about what is shipped.

## Primary product promise

Create a visual and show-control instrument that feels musical, immersive, reliable, and alive. It must react in a way that feels synchronized and authored, not random.

## Current major initiative: Unified Show Director

The next major architecture phase is a unified, typed show timeline and cue runtime supporting:

- DJ / electronic-performance mode driven by Traktor, Maschine, clocks, mappings, or normalized track events
- FOH / live-band mode driven by setlists, songs, sections, and manual or guided GO cues
- coordinated lighting, visual scenes, palettes, backdrop video, overlays, OBS, recording, and utility actions
- manual preset actions: Fire now, Insert next, Replace upcoming
- future iPhone and Apple Watch companion control
- non-destructive runtime overrides, undo, hold, park, and execution logs

These features are **planned architecture unless marked implemented in the audit**.

Mandatory reading for this initiative:

1. [`show-director-product-spec.md`](show-director-product-spec.md)
2. [`show-director-architecture.md`](show-director-architecture.md)
3. [`show-director-implementation-roadmap.md`](show-director-implementation-roadmap.md)
4. [`show-director-integrations.md`](show-director-integrations.md)
5. [`show-control-json-examples.md`](show-control-json-examples.md)
6. [`.cursor/rules/show_director.mdc`](../.cursor/rules/show_director.mdc)

## Core experience

A user should be able to:

- choose and validate audio input
- see signal, BPM, confidence, and beat state
- author and perform rich visual scenes
- patch fixtures and author lighting cues
- route visuals to an external display and Syphon
- save, archive, and reopen a show project
- control the live app from native UI, HTTP, WebSocket, OSC, and MIDI
- build a setlist of songs and sections
- execute one typed cue across multiple show endpoints
- override an unpredictable live performance safely and resume the authored show
- operate from a companion device without creating split-brain state

## Main personas

### DJ / original electronic performer

Needs track-aware scenes, musical clock synchronization, Remix Deck/Maschine event mappings, fast overrides, and a path from commercial-song practice to an original multimedia show.

### FOH show operator

Needs current/next cues, large GO control, setlist flexibility, endpoint health, hold/repeat/jump/park, and reliable remote operation while mixing audio.

### Visual operator / VJ

Needs fast scene switching, fullscreen reliability, external output, rich reactive behavior, and manual creative control.

### Show author

Needs typed cue packages, reusable palettes/presets, song sections, rehearsal timing, media validation, and project portability.

### Studio creator / brand artist

Needs cinematic ambience, overlays, themes, recording, and project-specific visual identity.

## Product values

- musical responsiveness
- deterministic show state
- operator authority
- visual richness and artistic identity
- safety and recoverability
- reliability without cloud dependency
- modular architecture and honest integration boundaries
- backward-compatible project evolution

## Existing architecture anchors

- `App/AppModel.swift` — current app coordinator; do not continue turning it into a monolith
- `Features/Scenes/` — visual scene data and persistence
- `Features/Renderer/` — Metal render passes
- `Features/Audio/` — input and analysis
- `Features/Lighting/` — fixtures, cues, stage, modulation
- `Features/Expansion/` — DMX, MIDI, OSC, recording, verification
- `Features/Web/` — HTTP/WebSocket state and command control
- `Features/Project/ProjectStack.swift` — project package persistence
- `App/LiveShowView.swift` and `LiveShowCueStripsView.swift` — current operator surface

Target new work belongs primarily in `Features/ShowControl/`, with isolated `OBS`, `Companion`, and routing services.

## Architectural rules

- SwiftUI owns UI composition.
- Audio analysis remains isolated from rendering.
- Rendering passes remain modular.
- Cue sources and cue destinations are decoupled.
- Show state changes flow through a deterministic reducer.
- Endpoint I/O happens through adapters and a serialized execution engine.
- Typed Codable actions replace loose executable metadata.
- The Mac host remains authoritative for companion clients.
- Secrets remain in Keychain, not project JSON.
- New project files are versioned and migrate older packages safely.
- No show-control operation may block Metal frame rendering.

## Quality bar

Every live feature must provide:

- accurate active and next state
- safe failure behavior
- clear connection health
- manual fallback
- deterministic tests where hardware is not required
- documented field/lab validation where hardware is required
- no misleading claim that inference or scaffolding is production-certified

## Recommended first coding slice

Do not begin with Watch, autonomous AI, or a custom virtual audio driver.

Start with:

1. typed show/setlist/action models,
2. Codable migrations,
3. deterministic reducer,
4. actor-isolated execution engine,
5. fake endpoint adapters,
6. adapters for existing scene/palette/lighting/overlay/backdrop systems,
7. project package additions,
8. a simple Guided-mode Setlist operator surface,
9. versioned HTTP show state/GO,
10. full tests and documentation sync.
