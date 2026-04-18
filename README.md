# FS-COS-VIS

## Cosmic Visualizer (beta)

FS-COS-VIS is a **hybrid macOS performance application**: real-time cosmic audio-reactive visualization, fractal + liquid-light scene authoring, live show controls, lighting patch/cue/modulation/stage workflows, fixture verification, and beta distribution/update support.

This repository is **no longer a starter scaffold**. It is a **late-stage beta** codebase with substantial implementation across rendering, audio/BPM, scene workflows, live output recording, web/MIDI/OSC control, lighting and stage planning, project packaging, and operator onboarding.

## Major app surfaces

- **Live Show** — performance preview, cue strips, tempo, recorder, haze safety, quick palette access  
- **Scene Studio** — scene editing, fractal/liquid/overlay authoring, **palette and overlay work consolidated here** (there is no separate Palette Browser or Overlay Manager app screen)  
- **Controller** — tempo, MIDI learn, faders, DMX group controls  
- **Settings** — remote control, OSC, audio, DMX transports, AI, updates, feedback, show package import/export  
- **Lighting Workspace** — patch, cues, stage, modulation, verification, JSON tools  

## Documentation (source-of-truth order)

1. This `README.md`  
2. [`docs/project-audit-and-feature-status.md`](docs/project-audit-and-feature-status.md)  
3. [`docs/07-roadmap.md`](docs/07-roadmap.md)  
4. [`docs/todo-full-implementation.md`](docs/todo-full-implementation.md)  
5. [`docs/03-ui-ux-spec.md`](docs/03-ui-ux-spec.md)  

Additional references:

- [`docs/lighting-roadmap.md`](docs/lighting-roadmap.md) — DMX/lighting detail  
- [`docs/beta-0.1a-release.md`](docs/beta-0.1a-release.md) — beta packaging and validation  
- [`docs/release-runbook.md`](docs/release-runbook.md) — Release CI, signing, notarization, Sparkle (Section K)  
- [`docs/osc-control.md`](docs/osc-control.md) — OSC operator quickstart  
- [`docs/macOS-installer-options.md`](docs/macOS-installer-options.md) — DMG vs ZIP vs PKG for testers  
- [`docs/fs-cos-vis-audit-and-docs-update/`](docs/fs-cos-vis-audit-and-docs-update/README_REPLACEMENT.md) — FS-COS-VIS audit pack (full project audit, alternate copies of roadmap/todo)  

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

## Drew Spaceman aesthetic

Treat **Drew Spaceman** as a defining aesthetic system: cosmic, psychedelic, analog-meets-futurist, immersive (not sterile), rich and cinematic. Start with:

- [`docs/01-cursor-context.md`](docs/01-cursor-context.md)  
- [`docs/06-drew-spaceman-aesthetic.md`](docs/06-drew-spaceman-aesthetic.md)  
- [`.cursor/rules.md`](.cursor/rules.md)  

## Building and testing

The Xcode project is generated from [`project.yml`](project.yml) using [XcodeGen](https://github.com/yonaskolb/XcodeGen). Signing uses a **local-only** [`project.local.yml`](project.local.yml.example) (copy from `project.local.yml.example`, set your Apple **DEVELOPMENT_TEAM**; file is gitignored). After cloning:

```bash
cp project.local.yml.example project.local.yml
# Edit project.local.yml — set DEVELOPMENT_TEAM to your 10-character Team ID
xcodegen generate
open CosmicVisualizer.xcodeproj
```

Or: `bash scripts/bootstrap-xcodegen.sh` creates `project.local.yml` from the example if missing.

Run tests from Xcode (**Cmd-U**) or from the terminal:

```bash
xcodebuild -scheme CosmicVisualizer -destination 'platform=macOS' test
```

CI also includes a **show package** smoke workflow (see [`.github/workflows/show-package-smoke.yml`](.github/workflows/show-package-smoke.yml)).

The app requires microphone access for live audio analysis (see Info usage string in `project.yml`). If permission is denied, use the in-app **Open Microphone Settings** action to jump to macOS Privacy settings, then retry audio start.

If the build fails with **missing Metal Toolchain** when compiling `.metal` files:

```bash
xcodebuild -downloadComponent MetalToolchain
```

The generated [CosmicVisualizer.xcodeproj](CosmicVisualizer.xcodeproj) is checked in so you can open the project without running XcodeGen; regenerate it whenever `project.yml` changes.
