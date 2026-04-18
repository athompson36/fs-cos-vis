# macOS Installer and Beta Distribution Options

## Current repo-supported path

The repository already supports packaging:
- ZIP
- DMG

Current release materials indicate the intended beta workflow is:
- Release build
- ZIP + DMG packaging
- signed/notarized artifacts
- Sparkle-compatible update path

## Recommended option for your beta tester

### Best choice: signed + notarized DMG
Why:
- easiest install experience
- no Xcode needed
- familiar drag-to-Applications flow
- best non-technical beta tester experience
- lowest Gatekeeper friction when signed/notarized

## Secondary option: signed ZIP
Good for:
- Sparkle appcast feed
- direct download/update archive

Tradeoff:
- less user-friendly than DMG
- more manual

## Optional future option: PKG installer
Use only if you want:
- guided install flow
- managed deployment
- enterprise-style install behavior

This is not the repo’s current primary packaging path.

## Recommended beta release workflow
1. build Release app
2. sign with Developer ID Application
3. notarize
4. generate DMG + ZIP
5. send DMG to tester
6. keep ZIP for Sparkle/appcast

## Minimum artifacts to hand off
- `CosmicVisualizer-<version>.dmg`
- optionally `CosmicVisualizer-<version>.zip`

## Before sending to tester
- validate install on a clean Mac without Xcode
- validate microphone permission prompt/recovery
- validate update check UI
- validate app launches without quarantine/signing confusion