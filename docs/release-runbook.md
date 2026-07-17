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

## Show Director package layout (SD-M0)

Approved foundation contract: [`docs/superpowers/specs/2026-07-16-show-director-foundation-design.md`](superpowers/specs/2026-07-16-show-director-foundation-design.md).

Inside an existing show package (marker: `project.json`):

```text
show-director/
  show.json
  setlists/<id>.json
  songs/<id>.json
  cue-packages/<id>.json
  presets/<id>.json
  logs/execution.jsonl
Media/
  video/
  images/
  overlays/
```

`schemaVersion` is required on Show Director root documents. Missing media under `Media/` is a validation **warning**; structural graph errors block installing a new graph.

## Version numbers (marketing vs build)

Set both in [`project.yml`](../project.yml) (then `xcodegen generate`):

| Setting | Meaning | Current |
|---------|---------|---------|
| `MARKETING_VERSION` | User-facing version (`CFBundleShortVersionString`) | `0.1` |
| `CURRENT_PROJECT_VERSION` | Monotonic build number (`CFBundleVersion`); Sparkle / Gatekeeper care about this | `1` |

**Bump strategy for beta tags (`v0.1a*`, Sparkle appcast items):**

1. Every shippable Release build: increment `CURRENT_PROJECT_VERSION` by 1 (never reuse).
2. User-visible beta label changes (0.1a → 0.1b, or 0.1 → 0.2): bump `MARKETING_VERSION` and reset or continue build number — prefer **continuing** the build number so Sparkle always sees a higher `CFBundleVersion`.
3. Tag / `GITHUB_REF_NAME` (e.g. `v0.1a1`) is the artifact filename label only; keep it aligned with marketing version in release notes.
4. After changing versions, regenerate (`xcodegen generate`) and verify `FSDMXVision.app/Contents/Info.plist`.

Copyright string: `INFOPLIST_KEY_NSHumanReadableCopyright` in `project.yml` (About panel / Finder Get Info).

## Local Release build (developer machine)

From the repo root:

```bash
brew install xcodegen   # if project not generated
cp -f project.local.yml.example project.local.yml   # once; then set DEVELOPMENT_TEAM in project.local.yml
xcodegen generate
xcodebuild -project FSDMXVision.xcodeproj -scheme FSDMXVision \
  -configuration Release -derivedDataPath build
```

App output expected by packaging:

`build/Build/Products/Release/FSDMXVision.app`

## Package DMG + ZIP

```bash
export GITHUB_REF_NAME="v0.1a-test"   # optional; default `beta-0.1a` in script
bash scripts/release/package-beta.sh
```

Artifacts land in `dist/`. Override build root if you use a different `derivedDataPath` layout:

```bash
export COSMIC_RELEASE_APP="/path/to/FSDMXVision.app"
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

Exact flags depend on embedded binaries; validate with `codesign -dv --verbose=4 FSDMXVision.app` after each step.

1. `codesign` all nested code (`.framework`, `.dylib`, helper tools) with your Developer ID identity.  
2. Sign the `.app` bundle with `--options runtime` and your Team ID.  
3. Zip the app for notary: `ditto -c -k --keepParent FSDMXVision.app FSDMXVision.zip`  
4. `xcrun notarytool submit FSDMXVision.zip --wait --keychain-profile "AC_PASSWORD"` (or Apple API key; see `notarytool --help`)  
5. `xcrun stapler staple FSDMXVision.app`  
6. Re-run `package-beta.sh` **after** stapling so DMG/ZIP contain the stapled app.

Until this is automated in CI, record **notarization submission ID** and ticket status for support escalations.

## Sparkle (ZIP + appcast)

The app links **Sparkle 2** (`AppUpdateService`). The feed keys are **wired in-repo**:

- Keys live in [`FSDMXVision/Info-Sparkle.plist`](../FSDMXVision/Info-Sparkle.plist), a **partial Info.plist merged** with the Xcode-generated one (`GENERATE_INFOPLIST_FILE=YES` + `INFOPLIST_FILE` in [`project.yml`](../project.yml)). Verified present in the built app's `Contents/Info.plist`.
  - `SUFeedURL` = `https://athompson36.github.io/fs-cos-vis/appcast.xml` — **update this** to wherever you actually host the appcast.
  - `SUPublicEDKey` = `h2G3DrLDQTmLO9Nq5fUBu5n9zNPRVhAB6Ml91K85nmM=` — EdDSA public key. The matching **private key is in the maintainer's login Keychain** (created by Sparkle's `generate_keys`). **Back it up and keep it off-repo** — it signs every update.
  - `SUEnableAutomaticChecks` = `false` — no background update prompts during a show; operators use Settings → **Check for updates**.

Per-release workflow:

1. Build **Release**, then package: `scripts/release/package-beta.sh` (produces `dist/FSDMXVision-<tag>.zip` + DMG).
2. **Sign + host the appcast:** `scripts/release/generate-appcast.sh` (wraps Sparkle's `generate_appcast`; signs each ZIP with the private key from the Keychain and writes `dist/appcast.xml`). Optionally set `COSMIC_DOWNLOAD_PREFIX` to the base URL where ZIPs are hosted.
3. Host `appcast.xml` **over HTTPS** at the `SUFeedURL` above, alongside the **signed, notarized ZIP**.
4. Test **Check for updates** from a Release build on a clean Mac.

> If the public/private keypair is ever rotated, re-run `generate_keys`, paste the new `SUPublicEDKey` into `Info-Sparkle.plist`, and re-sign the appcast.

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
