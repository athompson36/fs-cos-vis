# FS-COS-VIS

## FS DMX Vision (beta)

FS-COS-VIS is a **hybrid macOS performance application**: real-time cosmic audio-reactive visualization, fractal + liquid-light scene authoring, live show controls, lighting patch/cue/modulation/stage workflows, fixture verification, and beta distribution/update support.

This repository is **no longer a starter scaffold**. It is a **late-stage beta** codebase with substantial implementation across rendering, audio/BPM, scene workflows, live output recording, web/MIDI/OSC control, lighting and stage planning, project packaging, and operator onboarding.

## Major app surfaces

- **Live Show** — performance preview, cue strips, tempo, recorder, haze safety, quick palette access  
- **Scene Studio** — scene editing, fractal/liquid/overlay authoring, **palette and overlay work consolidated here** (there is no separate Palette Browser or Overlay Manager app screen)  
- **Controller** — tempo, MIDI learn, faders, DMX group controls  
- **Settings** — remote control, OSC, audio, DMX transports (**Art-Net / sACN over UDP on the LAN**, Wi‑Fi or Ethernet), AI, updates, feedback, show package import/export  
- **Lighting Workspace** — patch, cues, stage, modulation, verification, JSON tools  

## Documentation (source-of-truth order)

1. This `README.md`  
2. [`docs/project-audit-and-feature-status.md`](docs/project-audit-and-feature-status.md) — **single-page shipped vs gaps summary** (start here after README)  
3. [`docs/07-roadmap.md`](docs/07-roadmap.md)  
4. [`docs/todo-full-implementation.md`](docs/todo-full-implementation.md)  
5. [`docs/03-ui-ux-spec.md`](docs/03-ui-ux-spec.md)  

Additional references:

- [`docs/production-readiness-checklist.md`](docs/production-readiness-checklist.md) — **production pass:** gates, CI/lab/ops checklist, doc sync  
- [`docs/audit-execution-record.md`](docs/audit-execution-record.md) — **last full audit / verification run** (tests, packaging, manual-gate notes)  
- [`docs/ui-page-verification.md`](docs/ui-page-verification.md) — primary UI vs `03-ui-ux-spec` / code map  
- [`docs/feature-surface-matrix.md`](docs/feature-surface-matrix.md) — feature × surface summary (Gate 0.2)  
- [`docs/control-schema-coverage.md`](docs/control-schema-coverage.md) — web `ControlSchema` vs all remote commands (Gate 2.1)  
- [`docs/historical-docs-reconciliation.md`](docs/historical-docs-reconciliation.md) — audit pack vs live `docs/` (Gate 0.1)  
- [`docs/control-plane-smoke.md`](docs/control-plane-smoke.md) — OSC / HTTP / WS smoke (Gates 2.2–2.3)  
- [`docs/uat-checklist.md`](docs/uat-checklist.md) — manual product UAT walkthrough (Gate 4)  
- [`docs/lighting-roadmap.md`](docs/lighting-roadmap.md) — DMX/lighting detail  
- [`docs/dmx-lab-procedures.md`](docs/dmx-lab-procedures.md) — lab/field steps for Gate 3a / 3b.2 / 3c.2  
- [`scripts/README.md`](scripts/README.md) — operator scripts index  
- [`docs/control-parity.md`](docs/control-parity.md) — HTTP / MIDI / OSC vs `applyRemoteCommand`  
- [`docs/beta-0.1a-release.md`](docs/beta-0.1a-release.md) — beta packaging and validation  
- [`docs/release-runbook.md`](docs/release-runbook.md) — Release CI, signing, notarization, Sparkle (Section K)  
- [`docs/distribution-checklist.md`](docs/distribution-checklist.md) — Gate 5 sign / notarize / Sparkle worksheet  
- [`.github/workflows/README.md`](.github/workflows/README.md) — CI workflow index  
- [`docs/osc-control.md`](docs/osc-control.md) — OSC operator quickstart  
- [`docs/macOS-installer-options.md`](docs/macOS-installer-options.md) — DMG vs ZIP vs PKG for testers  
- [`docs/fs-cos-vis-audit-and-docs-update/`](docs/fs-cos-vis-audit-and-docs-update/README_REPLACEMENT.md) — **historical** audit pack snapshot (full narrative audit; live backlog is root `docs/`)  

**How production readiness is validated (in-repo, 2026-04):** Full macOS unit tests (`xcodebuild` / [`unit-tests-macos.yml`](.github/workflows/unit-tests-macos.yml)), show-package smoke ([`show-package-smoke.yml`](.github/workflows/show-package-smoke.yml)), Release packaging path ([`release-runbook.md`](docs/release-runbook.md)), operator scripts ([`uat-checklist.md`](docs/uat-checklist.md), [`control-plane-smoke.md`](docs/control-plane-smoke.md)). **Remaining work before ship:** [`docs/production-readiness-checklist.md`](docs/production-readiness-checklist.md) § **Next items (open gates)** (UAT → signed release → optional DMX field / relay).

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
open FSDMXVision.xcodeproj
```

Or: `bash scripts/bootstrap-xcodegen.sh` creates `project.local.yml` from the example if missing.

Run tests from Xcode (**Cmd-U**) or from the terminal:

```bash
xcodebuild -scheme FSDMXVision -destination 'platform=macOS' test
```

CI includes **show package** smoke ([`.github/workflows/show-package-smoke.yml`](.github/workflows/show-package-smoke.yml)) and optional **full unit tests** on macOS ([`.github/workflows/unit-tests-macos.yml`](.github/workflows/unit-tests-macos.yml)).

The app requires microphone access for live audio analysis (see Info usage string in `project.yml`). macOS remembers microphone consent per app in **System Settings → Privacy & Security → Microphone** until you revoke it. If you enable access there, the app picks it up when it becomes active again—no need to restart. If permission is denied, use the in-app **Open Microphone Settings** action to jump to Privacy settings, then return to the app or use **Retry audio start**.

If the build fails with **missing Metal Toolchain** when compiling `.metal` files:

```bash
xcodebuild -downloadComponent MetalToolchain
```

The generated [FSDMXVision.xcodeproj](FSDMXVision.xcodeproj) is checked in so you can open the project without running XcodeGen; regenerate it whenever `project.yml` changes.
