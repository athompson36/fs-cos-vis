#!/usr/bin/env bash
# Ensure project.local.yml exists (from example), then regenerate the Xcode project.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

if [[ ! -f project.local.yml ]]; then
  echo "Creating project.local.yml from project.local.yml.example — edit DEVELOPMENT_TEAM if needed."
  cp project.local.yml.example project.local.yml
fi

xcodegen generate
echo "OK: FSDMXVision.xcodeproj generated."
