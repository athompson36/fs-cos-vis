#!/usr/bin/env bash
# Package Release CosmicVisualizer.app as ZIP + DMG (UDZO).
# Prerequisites: Release build (see docs/release-runbook.md).
# Env:
#   COSMIC_RELEASE_APP — override path to .app (default: build/.../Release/CosmicVisualizer.app)
#   GITHUB_REF_NAME    — version label for filenames (default: beta-0.1a)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

APP_PATH="${COSMIC_RELEASE_APP:-build/Build/Products/Release/CosmicVisualizer.app}"
DIST_DIR="dist"
VERSION_TAG="${GITHUB_REF_NAME:-beta-0.1a}"

mkdir -p "${DIST_DIR}"

if [[ ! -d "${APP_PATH}" ]]; then
  echo "Missing app bundle at ${APP_PATH}"
  exit 1
fi

ZIP_PATH="${DIST_DIR}/CosmicVisualizer-${VERSION_TAG}.zip"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${ZIP_PATH}"

if command -v hdiutil >/dev/null 2>&1; then
  DMG_PATH="${DIST_DIR}/CosmicVisualizer-${VERSION_TAG}.dmg"
  hdiutil create -volname "CosmicVisualizer ${VERSION_TAG}" -srcfolder "${APP_PATH}" -ov -format UDZO "${DMG_PATH}"
fi

echo "Packaged release artifacts in ${DIST_DIR}"
