#!/usr/bin/env bash
set -euo pipefail

echo "[smoke] Installing xcodegen if missing"
if ! command -v xcodegen >/dev/null 2>&1; then
  brew install xcodegen
fi

echo "[smoke] Local XcodeGen signing stub (see project.local.yml.example)"
cp -f project.local.yml.example project.local.yml

echo "[smoke] Generating Xcode project"
xcodegen generate

echo "[smoke] Running show-package smoke tests"
xcodebuild test \
  -project "FSDMXVision.xcodeproj" \
  -scheme "FSDMXVision" \
  -destination "platform=macOS" \
  -only-testing:"FSDMXVisionTests/ShowProjectAndContextTests/testShowProjectPackageRoundTrip" \
  -only-testing:"FSDMXVisionTests/ShowProjectAndContextTests/testShowProjectArchiveExportImportRoundTrip"
