# macOS installer and beta distribution options

**Last updated:** 2026-04-17  

Companion to [`beta-0.1a-release.md`](beta-0.1a-release.md), [`release-runbook.md`](release-runbook.md), and [`README.md`](../README.md). Summarizes **how to hand builds to beta testers** without Xcode.

## Repo-supported packaging

The repository supports **ZIP** and **DMG** artifacts (see `scripts/release/package-beta.sh` and `.github/workflows/release-macos-beta.yml`). The intended workflow is **signed + notarized** macOS builds and a **Sparkle-compatible** update path for the ZIP/appcast side.

## Recommended option for most beta testers: signed + notarized DMG

- Easiest mental model: drag app to **Applications**  
- No Xcode required  
- Lowest Gatekeeper friction when properly signed and notarized  

## Secondary option: signed ZIP

- Good for **Sparkle appcast** distribution and lightweight direct downloads  
- Less friendly than DMG for non-technical users (may need manual drag to Applications)  

## Optional: PKG installer

- Can make sense for **enterprise** or guided installs  
- **Not** the repo’s primary documented path today; use only if requirements justify the extra packaging work  

## Recommended beta release workflow

1. Build **Release** app  
2. Sign with **Developer ID Application**  
3. **Notarize**  
4. Produce **DMG + ZIP**  
5. Hand **DMG** to testers for manual installs  
6. Keep **ZIP** for Sparkle/appcast  

## Minimum artifacts

- `FSDMXVision-<version>.dmg` (typical tester handoff)  
- Optionally `FSDMXVision-<version>.zip` (updates / automation)  

## Before sending to testers

Validate on a **clean Mac without Xcode** where possible:

- Install runs without unexplained quarantine/signing blocks  
- Microphone permission prompt and **in-app recovery** ([`beta-0.1a-release.md`](beta-0.1a-release.md))  
- Update check UI if applicable  
- Core flows: audio, Live Show, optional OSC spot-check ([`osc-control.md`](osc-control.md))  
