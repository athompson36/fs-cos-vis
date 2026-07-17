#!/usr/bin/env bash
# Generate + sign the Sparkle appcast for the ZIPs in dist/ (or $1).
#
# Sparkle's generate_appcast signs each update with the EdDSA PRIVATE key stored in your login
# Keychain (created by generate_keys — see docs/release-runbook.md). It writes appcast.xml into the
# archives directory. Host that appcast.xml at the SUFeedURL declared in FSDMXVision/Info-Sparkle.plist.
#
# Env:
#   ARCHIVES_DIR    — directory containing the release ZIP(s) (default: dist)
#   SPARKLE_BIN     — path to Sparkle's bin/ dir (default: auto-detect in DerivedData)
#   COSMIC_DOWNLOAD_PREFIX — optional base URL prepended to each enclosure url in the appcast
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

ARCHIVES_DIR="${ARCHIVES_DIR:-${1:-dist}}"

if [[ ! -d "${ARCHIVES_DIR}" ]]; then
  echo "Archives directory not found: ${ARCHIVES_DIR}" >&2
  exit 1
fi

# Locate generate_appcast (SPM artifact) unless SPARKLE_BIN is provided.
GEN_APPCAST="${SPARKLE_BIN:-}/generate_appcast"
if [[ -z "${SPARKLE_BIN:-}" || ! -x "${GEN_APPCAST}" ]]; then
  GEN_APPCAST="$(find "${HOME}/Library/Developer/Xcode/DerivedData" \
    -path '*/artifacts/sparkle/Sparkle/bin/generate_appcast' -type f 2>/dev/null | head -1 || true)"
fi

if [[ -z "${GEN_APPCAST}" || ! -x "${GEN_APPCAST}" ]]; then
  echo "Could not find Sparkle's generate_appcast. Build once (to resolve the Sparkle package)" >&2
  echo "or set SPARKLE_BIN to the Sparkle bin/ directory." >&2
  exit 1
fi

echo "Using generate_appcast: ${GEN_APPCAST}"
if [[ -n "${COSMIC_DOWNLOAD_PREFIX:-}" ]]; then
  "${GEN_APPCAST}" --download-url-prefix "${COSMIC_DOWNLOAD_PREFIX}" "${ARCHIVES_DIR}"
else
  "${GEN_APPCAST}" "${ARCHIVES_DIR}"
fi

echo "Wrote ${ARCHIVES_DIR}/appcast.xml — host it at the SUFeedURL in FSDMXVision/Info-Sparkle.plist."
