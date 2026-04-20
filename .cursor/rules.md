# Cursor Rules for FS DMX Vision

## Mission

Build a polished, modular, macOS-first audio-reactive visualization app with a strong Drew Spaceman cosmic-psychedelic identity.

## Non-negotiables

1. **When testing, fix and verify all errors and warnings before moving on to the next step.** After adding or changing tests or production code under test, run the full test action for the scheme (or `xcodebuild -scheme FSDMXVision -destination 'platform=macOS' test`). Resolve test failures, build errors, and compiler warnings introduced by that work—including Swift warnings and XCTest deprecations unless the project explicitly documents an exception—before starting the next task or module.
2. Do not flatten the app into a generic utility look.
3. Do not treat BPM detection as optional decoration; it is a functional driver.
4. Do not hardwire scene logic into view files.
5. Do not bury shader parameters across unrelated files.
6. Do not create monolithic render classes that mix UI, audio, and drawing responsibilities.
7. Do not remove liquid-light support from the architecture even if phase 1 starts simple.

## Testing

- Use **XCTest** in the `FSDMXVisionTests` target; prefer `@testable import FSDMXVision` for internal API.
- Prefer **protocols and fakes** at boundaries (audio buffers, beat clock) so analysis and state stay deterministic in CI.
- For Metal/renderers: unit-test **parameter packing, blend math, and pure Swift** helpers; use **minimal** integration tests for full frame paths when necessary.
- Do not merge or advance milestones on a red build or a warning baseline that regressed versus the previous step.

## Architecture rules

- SwiftUI owns UI composition.
- Audio analysis must be isolated from rendering.
- Rendering passes must be modular.
- Scene presets must be serializable.
- Themes and palettes must be data-driven.
- Overlay logic must be its own subsystem.
- Rendering code should be organized for future plugin/cross-platform reuse.

## UX rules

- previous / next controls must always be fast and obvious
- performance mode must hide nonessential editing chrome
- scene switching should support smooth transitions
- palette/theme changes should feel immediate
- BPM and beat state should be inspectable for debugging

## Aesthetic rules

Use the Drew Spaceman style guide as source of truth.

The app should feel:
- cosmic
- glowy
- immersive
- analog + futuristic
- psychedelic but intentional

Avoid:
- sterile monochrome dev dashboards
- generic EDM visual clichés only
- cheap rainbow overload without hierarchy
- flat, lifeless controls

## Coding rules

- favor clear naming over clever naming
- use small focused files
- document public models and managers
- create TODO comments only when concrete and actionable
- when scaffolding shaders, include parameter comments
- prefer extensions and feature folders over dumping files at root

## Build sequence

1. audio input + FFT + bpm detection
2. one fractal pass
3. one liquid-light pass
4. compositing pass
5. themes/palettes
6. overlays
7. scene persistence
8. fullscreen / external display polish

