# FS-COS-VIS

## FS DMX Vision (beta)

FS-COS-VIS is a **hybrid macOS performance application**: real-time cosmic audio-reactive visualization, fractal + liquid-light scene authoring, live show controls, lighting patch/cue/modulation/stage workflows, fixture verification, and beta distribution/update support.

This repository is **no longer a starter scaffold**. It is a **late-stage beta** codebase with substantial implementation across rendering, audio/BPM, scene workflows, live output recording, web/MIDI/OSC control, lighting and stage planning, project packaging, and operator onboarding.

## Current product vs next initiative

The current app ships the visual, lighting, project, remote-control, recording, and output foundations described below. The next major initiative is **Unified Show Director**: a typed setlist and cue runtime that will coordinate DMX lighting, visual scenes, backdrop video, overlays, OBS, DJ track metadata, FOH song sections, manual presets, and future iPhone/Apple Watch control.

Unified Show Director is an approved roadmap and architecture direction, **not a claim that those features are already implemented**. Start with:

1. [`docs/show-director-product-spec.md`](docs/show-director-product-spec.md)
2. [`docs/show-director-architecture.md`](docs/show-director-architecture.md)
3. [`docs/show-director-implementation-roadmap.md`](docs/show-director-implementation-roadmap.md)
4. [`docs/show-director-integrations.md`](docs/show-director-integrations.md)
5. [`docs/show-control-json-examples.md`](docs/show-control-json-examples.md)
6. [`.cursor/rules/show_director.mdc`](.cursor/rules/show_director.mdc)

## Major app surfaces

- **Live Show** — performance preview, cue strips, tempo, recorder, haze safety, quick palette access
- **Scene Studio** — scene editing, fractal/liquid/overlay authoring; palette and overlay work are intentionally consolidated here
- **Controller** — tempo, MIDI learn, faders, DMX group controls
- **Settings** — remote control, OSC, audio, DMX transports, AI, updates, feedback, show package import/export
- **Lighting Workspace** — patch, cues, stage, modulation, verification, JSON tools
- **Setlist / Show Director** — planned primary surface; see the implementation roadmap

## Documentation source-of-truth order

1. This `README.md`
2. [`docs/project-audit-and-feature-status.md`](docs/project-audit-and-feature-status.md)
3. [`docs/07-roadmap.md`](docs/07-roadmap.md)
4. [`docs/todo-full-implementation.md`](docs/todo-full-implementation.md)
5. [`docs/03-ui-ux-spec.md`](docs/03-ui-ux-spec.md)
6. Unified Show Director documents listed above for the new initiative

Additional references:

- [`docs/production-readiness-checklist.md`](docs/production-readiness-checklist.md)
- [`docs/audit-execution-record.md`](docs/audit-execution-record.md)
- [`docs/ui-page-verification.md`](docs/ui-page-verification.md)
- [`docs/feature-surface-matrix.md`](docs/feature-surface-matrix.md)
- [`docs/control-schema-coverage.md`](docs/control-schema-coverage.md)
- [`docs/control-plane-smoke.md`](docs/control-plane-smoke.md)
- [`docs/uat-checklist.md`](docs/uat-checklist.md)
- [`docs/lighting-roadmap.md`](docs/lighting-roadmap.md)
- [`docs/dmx-lab-procedures.md`](docs/dmx-lab-procedures.md)
- [`docs/control-parity.md`](docs/control-parity.md)
- [`docs/release-runbook.md`](docs/release-runbook.md)
- [`docs/distribution-checklist.md`](docs/distribution-checklist.md)
- [`docs/osc-control.md`](docs/osc-control.md)
- [`docs/macOS-installer-options.md`](docs/macOS-installer-options.md)
- [`docs/fs-cos-vis-audit-and-docs-update/`](docs/fs-cos-vis-audit-and-docs-update/README_REPLACEMENT.md) — historical audit snapshot only

## Honest production status

In-repo validation includes the macOS unit-test workflow, show-package smoke tests, release packaging scripts, and operator procedures. Remaining release work includes real UAT, signed/notarized clean-Mac distribution validation, optional DMX field gates, and optional hosted feedback relay. GitHub workflow definitions existing in the repository do not by themselves prove that every workflow or hardware gate has been run in the current environment.

## Recommended stack

- SwiftUI for app UI
- Metal for real-time rendering
- AVFoundation / Core Audio for device selection and capture
- Accelerate for FFT / spectral analysis
- FlyingFox for local HTTP/WebSocket control
- Syphon for texture sharing
- Sparkle for update delivery

## Primary goals

1. Build a responsive real-time visual instrument, not just a screensaver.
2. Support fractal, liquid-light, and hybrid scenes.
3. Make BPM and beat information musically useful.
4. Preserve strong cosmic identity with live-performance usability.
5. Coordinate visuals, lighting, media, overlays, and external systems through one reliable show runtime.
6. Support both DJ/original-performance automation and guided FOH setlist operation.
7. Keep the app modular so future companion, plugin, or cross-platform work remains possible.

## Drew Spaceman aesthetic

Treat **Drew Spaceman** as a defining aesthetic system: cosmic, psychedelic, analog-meets-futurist, immersive, rich, and cinematic. Start with:

- [`docs/01-cursor-context.md`](docs/01-cursor-context.md)
- [`docs/06-drew-spaceman-aesthetic.md`](docs/06-drew-spaceman-aesthetic.md)
- [`.cursor/rules.md`](.cursor/rules.md)

## Building and testing

The Xcode project is generated from [`project.yml`](project.yml) using XcodeGen. Signing uses a local-only `project.local.yml` copied from [`project.local.yml.example`](project.local.yml.example).

```bash
cp project.local.yml.example project.local.yml
# Edit project.local.yml and set DEVELOPMENT_TEAM.
xcodegen generate
open FSDMXVision.xcodeproj
```

Or run:

```bash
bash scripts/bootstrap-xcodegen.sh
```

Run tests:

```bash
xcodebuild -scheme FSDMXVision -destination 'platform=macOS' test
```

The app requires microphone access for live audio analysis. If access was denied, use the in-app **Open Microphone Settings** action, enable the app in **System Settings → Privacy & Security → Microphone**, return to the app, and retry audio start.

If the build fails because the Metal Toolchain is missing:

```bash
xcodebuild -downloadComponent MetalToolchain
```

The generated [`FSDMXVision.xcodeproj`](FSDMXVision.xcodeproj) is checked in. Regenerate it whenever `project.yml` changes.
