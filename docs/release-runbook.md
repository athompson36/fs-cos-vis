# Release runbook (Section K — signing, notarization, Sparkle)

**Audience:** maintainers shipping macOS builds outside Xcode-only workflows.  
**Companion docs:** [`macOS-installer-options.md`](macOS-installer-options.md), [`beta-0.1a-release.md`](beta-0.1a-release.md), [`todo-full-implementation.md`](todo-full-implementation.md) Section K.

## What CI does today

Workflow: [`.github/workflows/release-macos-beta.yml`](../.github/workflows/release-macos-beta.yml)

| Step | Status |
|------|--------|
| `xcodegen generate` | Yes |
| `xcodebuild` **Release** | Yes |
| `scripts/release/package-beta.sh` → DMG + ZIP | Yes |
| Artifact upload | Yes |
| Developer ID signing | **No** (needs cert + secrets) |
| Notarization | **No** (needs Apple ID / API key) |

CI produces **unsigned** Release bundles suitable for internal smoke tests only. Treat **signed + notarized** builds as a maintainer step until certificate secrets are wired into Actions (optional future work).

**Other workflows:** [`.github/workflows/README.md`](../.github/workflows/README.md) lists show-package smoke, full macOS unit tests, and the optional **notarize** dispatch **example** ([`notarize-macos-dispatch.yml.example`](../.github/workflows/notarize-macos-dispatch.yml.example)) — copy/rename and implement if you add signing secrets.

**Gate 5 worksheet:** [`distribution-checklist.md`](distribution-checklist.md) (sign / notarize / Sparkle / clean-Mac validation).

### Production checklist — Gate 1.4

[`production-readiness-checklist.md`](production-readiness-checklist.md) treats the **Release packaging path** as satisfied when:

1. **CI:** [`.github/workflows/release-macos-beta.yml`](../.github/workflows/release-macos-beta.yml) runs `xcodegen` (example `project.local.yml`), **Release** `xcodebuild` with `-derivedDataPath build`, then **`bash scripts/release/package-beta.sh`**, and uploads **`dist/*`** (ZIP + DMG when `hdiutil` is available).
2. **Local:** Same packaging script after a local Release build; see **Package DMG + ZIP** below.
3. **Signing:** Still **out of CI** by default — replace artifacts on the GitHub Release after **Developer ID + notarization** if shipping outside trusted testers.

This matches the steps in **What CI does today** and does not require a green **signed** build in Actions to check the box.

## Apple Developer Team (signing)

The generated Xcode project reads **`DEVELOPMENT_TEAM`** from **`project.local.yml`** (gitignored), merged via `project.yml` → `include`.

1. **First time:** `cp project.local.yml.example project.local.yml` (or `bash scripts/bootstrap-xcodegen.sh`).
2. Edit **`project.local.yml`**: set `DEVELOPMENT_TEAM` to your **10-character Team ID** (Xcode → Settings → Accounts, or [developer.apple.com](https://developer.apple.com/account) membership).
3. Run **`xcodegen generate`**, then open the project and confirm **Signing & Capabilities** shows the identity you expect (e.g. **Developer ID Application** for notarized distribution).

CI copies the example file (empty team) before `xcodegen` so automation keeps ad-hoc signing until you sign release artifacts locally.

## Local Release build (developer machine)

From the repo root:

```bash
brew install xcodegen   # if project not generated
cp -f project.local.yml.example project.local.yml   # once; then set DEVELOPMENT_TEAM in project.local.yml
xcodegen generate
xcodebuild -project CosmicVisualizer.xcodeproj -scheme CosmicVisualizer \
  -configuration Release -derivedDataPath build
```

App output expected by packaging:

`build/Build/Products/Release/CosmicVisualizer.app`

## Package DMG + ZIP

```bash
export GITHUB_REF_NAME="v0.1a-test"   # optional; default `beta-0.1a` in script
bash scripts/release/package-beta.sh
```

Artifacts land in `dist/`. Override build root if you use a different `derivedDataPath` layout:

```bash
export COSMIC_RELEASE_APP="/path/to/CosmicVisualizer.app"
bash scripts/release/package-beta.sh
```

(`package-beta.sh` respects `COSMIC_RELEASE_APP` when set — see script header.)

## Signing and notarization (manual path)

Requirements:

- **Apple Developer Program** membership  
- **Developer ID Application** certificate installed in Keychain  
- **Hardened Runtime** is already enabled in `project.yml` (`ENABLE_HARDENED_RUNTIME: YES`)  
- App embeds **Syphon** and Swift packages; sign **inside-out** (helpers → frameworks → app). Prefer **Xcode Organizer → Archive → Distribute App → Developer ID → Upload** for the least error-prone first notarization, then align command-line scripts with that provenance.

### Command-line sketch (expert use)

Exact flags depend on embedded binaries; validate with `codesign -dv --verbose=4 CosmicVisualizer.app` after each step.

1. `codesign` all nested code (`.framework`, `.dylib`, helper tools) with your Developer ID identity.  
2. Sign the `.app` bundle with `--options runtime` and your Team ID.  
3. Zip the app for notary: `ditto -c -k --keepParent CosmicVisualizer.app CosmicVisualizer.zip`  
4. `xcrun notarytool submit CosmicVisualizer.zip --wait --keychain-profile "AC_PASSWORD"` (or Apple API key; see `notarytool --help`)  
5. `xcrun stapler staple CosmicVisualizer.app`  
6. Re-run `package-beta.sh` **after** stapling so DMG/ZIP contain the stapled app.

Until this is automated in CI, record **notarization submission ID** and ticket status for support escalations.

## Sparkle (ZIP + appcast)

The app links **Sparkle 2** (`AppUpdateService`). For updates to resolve in production builds:

1. Add **`SUFeedURL`** (and **`SUPublicEDKey`**) via `project.yml` `INFOPLIST_KEY_*` or an Info.plist — coordinate with hosting URL for `appcast.xml`.  
2. Generate Sparkle **edDSA** keys (`./bin/generate_keys` from Sparkle distribution); keep the **private** key off-repo; publish the **public** key in Info.plist.  
3. Host **`appcast.xml`** over HTTPS; each release adds an `<item>` pointing at the **signed, notarized ZIP** (Sparkle signs updates with `sign_update` or equivalent).  
4. Test **Check for updates** from a Release build on a clean Mac.

Full Sparkle workflow: [Sparkle documentation](https://sparkle-project.org/documentation/).

## GitHub Release handoff

1. Tag: `git tag v0.1a1 && git push origin v0.1a1` (matches workflow `v0.1a*` filter).  
2. Run workflow or wait for tag-triggered run.  
3. Download `dist` artifact; after signing/notarizing locally, replace artifacts on the GitHub Release with production DMG/ZIP.  
4. Update appcast if using Sparkle.

## Clean Mac validation (no Xcode)

Use a machine without Xcode to reduce “works on my dev kit” drift:

- Open DMG, drag to Applications, first launch (Gatekeeper / quarantine).  
- Microphone permission + **Open Microphone Settings** recovery — [`beta-0.1a-release.md`](beta-0.1a-release.md).  
- Optional OSC spot-check — [`osc-control.md`](osc-control.md).  
- App updates UI if Sparkle feed is live.

## PKG installer

Deferred as non-primary; see [`macOS-installer-options.md`](macOS-installer-options.md).

## Optional: CI signing later

To **prove** signed + notarized builds in GitHub Actions, you would typically add:

- Encrypted **p12** + password → import to temporary keychain  
- `notarytool` with App Store Connect API key or Apple ID app-specific password in secrets  
- Staple before `package-beta.sh`

Do not commit certificates or notarization passwords; use repository secrets only.
