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
  -project "CosmicVisualizer.xcodeproj" \
  -scheme "CosmicVisualizer" \
  -destination "platform=macOS" \
  -only-testing:"CosmicVisualizerTests/ShowProjectAndContextTests/testShowProjectPackageRoundTrip" \
  -only-testing:"CosmicVisualizerTests/ShowProjectAndContextTests/testShowProjectArchiveExportImportRoundTrip"
