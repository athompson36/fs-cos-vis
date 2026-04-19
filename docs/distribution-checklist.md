# Distribution checklist (production Gate 5)

**When:** After **Gate 4** (UAT) is acceptable for your beta — see [`production-readiness-checklist.md`](production-readiness-checklist.md) § **Next items (open gates)**.

**Purpose:** Maintainer-facing worksheet aligned with [`production-readiness-checklist.md`](production-readiness-checklist.md) Gate 5 and [`todo-full-implementation.md`](todo-full-implementation.md) Section K. Detailed procedures live in [`release-runbook.md`](release-runbook.md), [`macOS-installer-options.md`](macOS-installer-options.md), and [`beta-0.1a-release.md`](beta-0.1a-release.md).

**CI today:** [`.github/workflows/release-macos-beta.yml`](../.github/workflows/release-macos-beta.yml) produces **unsigned** DMG/ZIP. Signing and notarization are **manual** (or a custom workflow) until secrets are wired.

**Optional Actions skeleton:** [`.github/workflows/notarize-macos-dispatch.yml.example`](../.github/workflows/notarize-macos-dispatch.yml.example) — rename and implement per runbook; not enabled by default.

| # | Task | Owner / notes |
|---|------|----------------|
| 5.1 | Developer ID sign (nested code: helpers → frameworks → app; Syphon order per runbook) | |
| 5.2 | `notarytool submit` + **staple**; record submission ID for support | |
| 5.3 | DMG for testers; ZIP for Sparkle | |
| 5.4 | Sparkle: `SUFeedURL`, `SUPublicEDKey`, hosted `appcast.xml`; test **Check for updates** on Release | |
| 5.5 | Clean Mac **without Xcode** — run [`beta-0.1a-release.md`](beta-0.1a-release.md) validation bullets | |

**Exit:** At least one **signed + notarized** artifact proven end-to-end; then check Gate 5 in the production checklist.
