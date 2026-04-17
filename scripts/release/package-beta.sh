#!/usr/bin/env bash
set -euo pipefail

APP_PATH="build/Build/Products/Release/CosmicVisualizer.app"
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
