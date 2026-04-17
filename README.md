# Cosmic Visualizer Cursor Starter

A Cursor-ready starter package for building a macOS-native, audio-reactive fractal and liquid-light visualization app.

This starter is designed to help Cursor understand:
- the product vision
- the technical architecture
- the visual direction
- the implementation sequence
- the Drew Spaceman aesthetic and brand tone

## Included

- detailed product and UX documentation
- Cursor-specific context and rules
- a recommended macOS-first architecture
- starter Swift/Metal project structure
- scene, theme, BPM, overlay, and rendering guidance

## Current implementation status

Cosmic Visualizer has progressed beyond starter scaffolding into a substantial implementation:

- core scene/render/audio workflow is in place
- performance/live control surfaces are implemented
- lighting stack includes patch/cues/modulation/stage/2.5D preview
- fog/haze learn and fixture verification workflows are implemented
- OFL fixture import and curated catalog sync are integrated
- stage plot supports fixture placement, gear objects, and scan-camera overlays
- cue bookmarks now support metadata (for example song title/artist), and overlay elements support metadata binding + per-element auto-hide timeout
- Live Show includes project-scoped output recording (video + audio) with source selection and share/reveal actions
- fractal zoom now includes Standard / Infinite Tunnel / Event Horizon modes with expanded zoom modulation range
- first-run Setup Wizard (beta 0.1a) now guides project/audio/output/DMX/AI setup with skippable steps and provider-specific AI API onboarding links/instructions (OpenAI-compatible vs Claude/Anthropic)
- audio startup now requests microphone permission explicitly and includes one-click recovery actions to open macOS Microphone Privacy settings if access is denied after a new build/install
- Settings now includes beta update checks and dual-path feedback/error-log reporting (local bundle + optional GitHub issue)

For full details, see:

- `docs/project-audit-and-feature-status.md`
- `docs/lighting-roadmap.md`
- `docs/todo-full-implementation.md`
- `docs/beta-0.1a-release.md`

## Recommended stack

- SwiftUI for app UI
- Metal for real-time rendering
- AVFoundation / Core Audio for device selection and capture
- Accelerate for FFT / spectral analysis

## Primary goals

1. Build a responsive real-time visual instrument, not just a screensaver.
2. Support fractal, liquid-light, and hybrid scenes.
3. Make BPM and beat information musically useful.
4. Preserve strong cosmic identity with live-performance usability.
5. Keep the app modular so future Windows or plugin versions are possible.

## Important design note

"Drew Spaceman" should be treated as a defining aesthetic system for the app:
- cosmic
- psychedelic
- analog-meets-futurist
- immersive, not sterile
- rich, glowy, cinematic, musical

Start with:
- `docs/01-cursor-context.md`
- `docs/06-drew-spaceman-aesthetic.md`
- `.cursor/rules.md`

## Building and testing

The Xcode project is generated from [project.yml](project.yml) using [XcodeGen](https://github.com/yonaskolb/XcodeGen). After cloning:

```bash
xcodegen generate
open CosmicVisualizer.xcodeproj
```

Run tests from Xcode (**Cmd-U**) or from the terminal:

```bash
xcodebuild -scheme CosmicVisualizer -destination 'platform=macOS' test
```

The app requires microphone access for live audio analysis (see Info usage string in `project.yml`). If permission is denied, use the in-app **Open Microphone Settings** action to jump directly to macOS Privacy settings and then retry audio start.

If the build fails with **missing Metal Toolchain** when compiling `.metal` files, install Apple’s component:

```bash
xcodebuild -downloadComponent MetalToolchain
```

The generated [CosmicVisualizer.xcodeproj](CosmicVisualizer.xcodeproj) is checked in so you can open the project without running XcodeGen; regenerate it whenever `project.yml` changes.

