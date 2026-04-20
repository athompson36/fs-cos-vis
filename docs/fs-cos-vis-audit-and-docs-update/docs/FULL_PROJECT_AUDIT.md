# FS-COS-VIS Full Project Audit
Date: 2026-04-17

## Executive summary

FS-COS-VIS is no longer a starter. It is a substantial late-stage macOS application that combines:
- cosmic audio-reactive visualization
- scene-based fractal + liquid-light rendering
- live show control surfaces
- lighting patch/cue/modulation/stage planning
- fixture verification and transport scaffolding
- beta distribution and updater preparation

The codebase shows strong forward progress, but the project is not “documentation-coherent” yet.
The largest current problem is not missing core architecture. It is drift:
- docs do not all describe the same current product state
- some UI expectations are documented in older spec files but already intentionally consolidated in the app
- the backlog file is behind the roadmap
- the README title still undersells the repo and no longer matches the implementation

## Repo-verified implementation status

### Core visualizer systems: implemented
- live scene switching
- scene studio/editor
- fractal + liquid-light renderer
- composite renderer
- palette/theme systems
- external display output
- live output recorder
- overlay import and black-background removal flow
- BPM and beat-confidence display
- setup-wizard related release/runbook docs

### Audio systems: implemented
- audio input device selection
- input channel selection
- FFT / audio feature extraction
- BPM feeds
- microphone permission recovery actions
- OBS forwarding support paths

### Control systems: mostly implemented, partial parity
- native control surfaces
- HTTP + WebSocket remote control
- MIDI mapping
- OSC control docs and Settings controls are present
- OSC parity appears significantly advanced, but it should still be verified against every important native command path

### Lighting/show systems: substantially implemented
- fixture profiles
- patching
- cue editing / ordering / duplication
- modulation
- stage plan
- 2.5D preview
- backdrop cues
- OFL import
- camera-assisted fog/haze learning
- fixture verification workflow
- JSON transport/import/export tools

### Distribution/release systems: partially implemented
- packaging script for ZIP and DMG
- GitHub Actions beta release workflow
- Sparkle-compatible release runbook docs
- update check UI in Settings
- signed/notarized workflow intent documented, but not fully proven by repo contents alone

## Documentation status audit

### README.md
Current state:
- partially current
- implementation bullets are much more current than the title/subtitle
Problem:
- still framed as “FS DMX Vision Cursor Starter”
Recommendation:
- rename positioning from starter to beta app / hybrid visualizer + show-control platform

### docs/project-audit-and-feature-status.md
Current state:
- partially current
Problem:
- lags behind the newer roadmap
- does not mention some newer shipped items reflected elsewhere:
  - live output recorder
  - setup wizard
  - beta update checks
  - feedback/error-log workflow
  - OSC docs/status
  - package import/export automation
Recommendation:
- replace with a fresh full-status audit

### docs/todo-full-implementation.md
Current state:
- outdated relative to roadmap
Problem:
- still lists some items as backlog that roadmap now marks as started or implemented
- does not reflect intentional consolidation decisions
Recommendation:
- rewrite from current roadmap reality, not older assumptions

### docs/03-ui-ux-spec.md
Current state:
- outdated
Problem:
- still says Palette Browser and Overlay Manager are primary screens
- current roadmap indicates these are intentionally consolidated into Scene Studio
- Performance View spec still needs adjustment to match current implemented controls
Recommendation:
- revise spec to describe actual shipped IA and remaining true UI gaps

### docs/07-roadmap.md
Current state:
- most current major planning doc
Strength:
- best high-level reflection of recent progress
Caution:
- should become the source of truth for roadmap status, then bring other docs into alignment

### docs/lighting-roadmap.md
Current state:
- relatively current
Strength:
- matches major lighting implementation progress well
Caution:
- still labels some items “scaffold” or “next” and should be kept tightly aligned with actual transport progress

### docs/beta-0.1a-release.md
Current state:
- useful and current for beta workflow
Strength:
- best source for packaging/release process

### docs/osc-control.md
Current state:
- useful and current
Strength:
- indicates meaningful OSC implementation and operator-facing usage

## App page audit

## 1. Root navigation
Current top-level pages:
- Live Show
- Scene Studio
- Controller
- Settings
- Lighting

Strengths:
- clear functional separation
- major workflows are represented

Weaknesses:
- the app is broad enough now that TabView is becoming crowded
- Lighting contains a very large amount of authoring/operations functionality in one area
- a sidebar navigation model may eventually scale better than a flat tab bar

## 2. Live Show
Observed:
- performance toggle
- audio selection
- emergency haze kill
- preview
- cue strips
- BPM/beat status
- prev/next/random/fullscreen
- quick palette access
- recorder controls
- overlay/liquid toggles

Strengths:
- strong live-use focus
- quick palette access is now present
- recorder controls are surfaced in the live workflow
- haze emergency controls are prominent

Gaps / issues:
- no obvious input meter visible in this view
- beat information is present as confidence text, but not a strong visual pulse indicator
- live action controls are becoming vertically stacked and busy
- recorder controls are useful, but visually dense relative to performance-critical actions
- import/remove-black actions are mixed into the main action row and feel more authoring-oriented than live-oriented

Recommendation:
- split the top action band into:
  - performance actions
  - palette/look actions
  - capture/output actions
- add a clear level meter and beat pulse widget
- move authoring-adjacent overlay asset actions behind a compact disclosure or utility menu

## 3. Scene Studio
Observed:
- live preview
- scene list
- fractal controls
- scene look controls
- liquid controls
- overlay authoring
- palette creation/selection
- dropper layer editing

Strengths:
- coherent creative authoring surface
- consolidation of palette/overlay work into Scene Studio is logical
- preview remains central

Gaps / issues:
- density is high
- too many responsibilities live in a single surface
- control grouping is mostly good, but still heavy for a new user
- the page would benefit from clearer sub-mode segmentation:
  - scene
  - fractal
  - liquid
  - overlays
  - palettes

Recommendation:
- keep consolidation, but introduce stronger sectional navigation
- use collapsible cards with saved expansion state
- consider a segmented top control for:
  - Scene
  - Look
  - Liquid
  - Overlay
  - Palette

## 4. Controller
Observed:
- overview tab
- tempo controls
- learn mode
- faders
- DMX control groups
- status information

Strengths:
- useful control-focused surface
- good place for performance mapping concepts
- separates overview from faders

Gaps / issues:
- still reads like an engineering/control surface rather than a polished operator surface
- disabled/planned controls need very clear labeling
- mapping visibility could be stronger
- vertical slider density may become overwhelming with larger rigs

Recommendation:
- add mapping summary cards
- add filter/search for fader groups
- visually separate:
  - scene parameters
  - DMX fixture controls
  - learned controls
- improve inactive/planned state styling

## 5. Settings
Observed:
- build/beta status
- updates
- feedback/error logs
- show package archive export/import
- AI settings
- remote control
- OSC
- audio routing
- DMX output/inbound/RDM scaffolds

Strengths:
- broad operational coverage
- beta workflow support is good
- packaging/import/export surfaced
- remote and OSC controls are present

Gaps / issues:
- Settings is carrying both configuration and transport scaffolding
- some sections are now advanced enough that they may deserve their own admin/setup tools
- DMX transport settings are extensive and could overwhelm non-technical beta users

Recommendation:
- keep Settings for now, but consider subpages or grouped panes
- add “Basic / Advanced” disclosure for transport-heavy controls
- separate everyday beta-tester settings from power-user transport settings

## 6. Lighting workspace
Observed:
- patch/stage tab
- modulation/tools tab
- patching, OFL import, cue editing, backdrop cues, stage plan, 2.5D preview
- modulation controls
- JSON transport/import/export
- fixture verification and scan wizard
- copilot helpers

Strengths:
- highly capable
- serious workflow depth
- patch/cue/stage/verification all represented
- strong utility for show planning

Gaps / issues:
- this page is doing a lot
- it is the most overloaded area in the app
- JSON transport is powerful but bulky in the main workspace
- patching, verification, and transport utilities are mixed together
- operator cognition cost is high

Recommendation:
- break Lighting into stronger sub-navigation:
  - Patch
  - Cues
  - Stage
  - Verify
  - Tools
- move JSON transport to a Tools or Advanced tab
- keep verification wizard visually isolated and easier to resume

## UI layout / control organization findings

### Strong
- consistent SwiftUI structure
- grouped controls
- practical show-first controls in Live Show
- Scene Studio consolidation is defensible
- recorder/feedback/update pipeline is now product-real

### Weak / disorganized
- not enough hierarchy between live controls and authoring tools
- some authoring controls remain visible in live contexts
- Settings and Lighting are absorbing too many advanced responsibilities
- documentation still describes some older IA assumptions

## Missing or unclear UI elements

### Likely still missing or weak
- explicit audio input meter on Live Show
- strong beat pulse indicator / visual beat widget
- more obvious “now active scene / palette / cue” summary band
- better separation of live-safe controls vs setup/authoring controls
- stronger transport diagnostic grouping in Settings
- search/filter for larger patch/cue/fader environments

### Not truly missing, but documentation should be updated
- dedicated Palette Browser screen
- dedicated Overlay Manager screen

These appear to be intentionally consolidated into Scene Studio and should be documented that way instead of tracked as missing standalone pages.

## Full feature set implementation status

### Implemented or substantially implemented
- core live visualizer
- scene editing
- fractal/liquid/composite rendering
- audio selection and BPM-driven workflow
- external output
- recorder
- web control
- MIDI control
- OSC control surface
- patching
- cues
- stage layout
- 2.5D preview
- OFL import
- fog/haze learn
- fixture verification
- beta update checks
- feedback/error-log workflows
- project package import/export UI

### Started / scaffolded / partial
- Art-Net output
- sACN output
- inbound DMX
- RDM discovery/probing
- DMX performance diagnostics
- Sparkle publication/signing automation hardening

### Still not complete enough to call finished
- deterministic verification test coverage
- final operator UX polish in stage/verification flows
- polished transport/admin information architecture
- full docs/spec coherence
- proven end-to-end signed/notarized beta release path

## Installer / beta tester options (macOS without Xcode)

### Best option: signed + notarized DMG
This is the best choice for a normal beta tester.
Why:
- easiest to understand
- familiar macOS install flow
- least confusion
- works without Xcode
- avoids most Gatekeeper friction when properly signed/notarized

Repo evidence:
- packaging script already builds a DMG
- release workflow already packages release artifacts
- beta release runbook explicitly targets signed/notarized beta artifacts

### Also useful: signed ZIP
Good for:
- Sparkle appcast distribution
- lightweight direct download

Tradeoff:
- less friendly than DMG for non-technical testers
- user may still need to drag app manually

### Possible but not currently primary: PKG installer
Pros:
- guided install flow
- can place app in /Applications
- good for enterprise rollout

Cons:
- more setup complexity
- not currently the repo’s documented packaging path
- less aligned with current Sparkle-oriented beta workflow

### Recommended beta distribution path
1. build Release app
2. sign with Developer ID Application
3. notarize
4. package DMG + ZIP
5. send DMG directly to tester
6. keep ZIP for Sparkle/appcast use

## Current doc update recommendation

Source of truth should become:
1. README
2. docs/project-audit-and-feature-status.md
3. docs/07-roadmap.md
4. docs/todo-full-implementation.md
5. docs/03-ui-ux-spec.md

These should all be rewritten/aligned from the current roadmap reality.

## Final conclusion

The project is substantially implemented and beta-capable, but not documentation-clean yet.
The most important remaining work is:
- doc/spec alignment
- UI hierarchy polish
- transport/admin surface cleanup
- verification hardening
- release-path proofing