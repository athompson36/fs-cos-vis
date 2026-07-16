# Cursor Rules for FS DMX Vision

## Mission

Build a polished, modular, macOS-first audio-reactive visualization and show-control app with a strong Drew Spaceman cosmic-psychedelic identity.

## Required context

Before substantial work, read:

1. `README.md`
2. `docs/01-cursor-context.md`
3. `docs/project-audit-and-feature-status.md`
4. `docs/07-roadmap.md`
5. `docs/todo-full-implementation.md`

For Unified Show Director work also read:

- `docs/show-director-product-spec.md`
- `docs/show-director-architecture.md`
- `docs/show-director-implementation-roadmap.md`
- `docs/show-director-integrations.md`
- `docs/show-control-json-examples.md`
- `.cursor/rules/show_director.mdc`

Never describe a roadmap item as shipped unless the code and project audit support that claim.

## Non-negotiables

1. **When testing, fix and verify all errors and warnings before moving on to the next step.** After adding or changing tests or production code under test, run the full test action for the scheme or `xcodebuild -scheme FSDMXVision -destination 'platform=macOS' test`. Resolve introduced test failures, build errors, compiler warnings, and XCTest deprecations unless the project explicitly documents an exception.
2. Do not flatten the app into a generic utility look.
3. Do not treat BPM detection as optional decoration; it is a functional driver.
4. Do not hardwire scene or show logic into view files.
5. Do not bury shader parameters across unrelated files.
6. Do not create monolithic render classes that mix UI, audio, drawing, endpoint, and timeline responsibilities.
7. Do not remove liquid-light support from the architecture.
8. Do not turn `AppModel` into the implementation home for every new subsystem.
9. Do not use arbitrary string dictionaries as the canonical executable show-action model.
10. Do not make live operation depend on cloud availability.
11. Do not imply that inferred song sections, mock RDM, counted sACN packets, or unrun field gates are equivalent to deterministic/field-certified behavior.
12. Do not break existing scenes, lighting projects, archives, HTTP/OSC/MIDI commands, or Live Show workflows while adding Show Director.

## Testing

- Use XCTest in the `FSDMXVisionTests` target; prefer `@testable import FSDMXVision` for internal API.
- Prefer protocols and fakes at audio, clock, endpoint, network, and hardware boundaries.
- For Metal/renderers, unit-test parameter packing, blend math, and pure Swift helpers; use minimal integration tests for full frame paths when necessary.
- For Show Director, unit-test reducers, migrations, action ordering, idempotency, overrides, undo, state-version conflicts, and reconnect/resync.
- Do not merge or advance milestones on a red build or a warning baseline that regressed.
- Hardware and live-network claims require documented lab/field evidence in addition to CI.

## Architecture rules

- SwiftUI owns UI composition.
- Audio analysis is isolated from rendering.
- Rendering passes are modular.
- Scene presets are serializable.
- Themes and palettes are data-driven.
- Overlay logic is its own subsystem.
- Rendering code remains organized for future plugin/cross-platform reuse.
- Cue sources and cue destinations are decoupled.
- Show documents and actions are typed, versioned, and Codable.
- A deterministic reducer owns state transitions; reducers perform no I/O.
- A serialized execution engine owns endpoint effects and command idempotency.
- OBS, Traktor, Maschine, companion, video, and audio-routing behavior live behind adapters/services.
- The Mac host is authoritative for remote/companion show state.
- Project migrations preserve older `.cosmicshow.zip` packages.
- Secrets live in Keychain, never show packages or logs.

## UX rules

- previous/next controls remain fast and obvious
- performance mode hides nonessential editing chrome
- scene switching supports smooth transitions
- palette/theme changes feel immediate
- BPM and beat state are inspectable for debugging
- Setlist Run mode prioritizes current cue, next cue, GO, hold, health, and recovery
- authoring density stays out of the live operator surface
- manual presets clearly distinguish Fire now, Insert next, and Replace upcoming
- automation mode and inference confidence are always visible
- remote actions do not show success before host acknowledgement

## Safety rules

- Haze emergency kill remains a final non-bypassable override.
- Lighting blackout and video blackout are separate.
- Park, strobe kill, movement stop, undo, and safe restore remain available during endpoint failures.
- High-risk remote actions require explicit enablement and confirmation/hold behavior.
- Never hold the lighting lock across async work.
- No show-control task may block Metal frame rendering.

## Aesthetic rules

Use the Drew Spaceman style guide as source of truth.

The app should feel:

- cosmic
- glowy
- immersive
- analog + futuristic
- psychedelic but intentional
- cinematic and legible under low light

Avoid:

- sterile monochrome dev dashboards
- generic EDM visual clichés only
- cheap rainbow overload without hierarchy
- flat, lifeless controls
- muddy interfaces that hide live state

## Coding rules

- favor clear naming over clever naming
- use small focused files
- document public models, managers, adapters, and migration behavior
- create TODO comments only when concrete and actionable
- when scaffolding shaders, include parameter comments
- prefer extensions and feature folders over dumping files at root
- use stable UUID references across show documents
- keep authored state distinct from runtime overrides and run logs
- return structured endpoint results instead of swallowing errors

## Historical build sequence

The original visualizer sequence was:

1. audio input + FFT + BPM detection
2. fractal pass
3. liquid-light pass
4. compositing pass
5. themes/palettes
6. overlays
7. scene persistence
8. fullscreen / external-display polish

Those foundations now exist. The next sequence is defined in `docs/show-director-implementation-roadmap.md`; begin with typed models, reducer, execution engine, existing endpoint adapters, persistence, Setlist UI, and tests before companion or AI work.
