# GitHub Actions workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| [`show-package-smoke.yml`](show-package-smoke.yml) | push/PR to `main`/`master`, `workflow_dispatch` | Fast CI: XcodeGen + narrow show-package tests |
| [`unit-tests-macos.yml`](unit-tests-macos.yml) | push/PR to `main`/`master`, `workflow_dispatch` | Full `CosmicVisualizer` unit test suite on macOS |
| [`release-macos-beta.yml`](release-macos-beta.yml) | `workflow_dispatch`, tags `v0.1a*` | Release build + `package-beta.sh` → artifact upload (**unsigned**) |
| [`notarize-macos-dispatch.yml.example`](notarize-macos-dispatch.yml.example) | (not active) | Skeleton for future signing/notarization; copy/rename and add secrets |

Local mirrors: `scripts/ci/smoke-show-package.sh`, full tests per [`README.md`](../../README.md). Signing: [`docs/release-runbook.md`](../../docs/release-runbook.md).
