# Scripts index

| Path | Role |
|------|------|
| [`ci/smoke-show-package.sh`](ci/smoke-show-package.sh) | Local mirror of show-package CI smoke (`xcodegen` + two focused tests) |
| [`ci/smoke-control-plane.sh`](ci/smoke-control-plane.sh) | HTTP remote smoke — requires app running ([`docs/control-plane-smoke.md`](../docs/control-plane-smoke.md)) |
| [`release/package-beta.sh`](release/package-beta.sh) | DMG + ZIP from Release `.app` ([`docs/release-runbook.md`](../docs/release-runbook.md)) |
| [`osc/`](osc/) | OSC helpers (`send.sh`, `query-state.sh`, `osc_control.py`, examples) |
| [`feedback-relay/`](feedback-relay/) | Optional Node relay for GitHub issue submission ([`README.md`](feedback-relay/README.md)) |
| [`bootstrap-xcodegen.sh`](bootstrap-xcodegen.sh) | Create `project.local.yml` from example if missing |
| [`generate_app_icon.py`](generate_app_icon.py) | Build liquid-glass macOS `AppIcon` set from [`docs/icon.png`](../docs/icon.png) → `FSDMXVision/.../Assets.xcassets` (uses `build/genicon-venv` + Pillow; run `xcodegen generate` after) |

CI workflows: [`.github/workflows/README.md`](../.github/workflows/README.md).
