#!/usr/bin/env bash
set -euo pipefail

# OSC quick examples for Cosmic Visualizer operators.
# Requires OSC UDP control enabled in-app (Settings > Remote control).

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SEND="${ROOT_DIR}/scripts/osc/send.sh"
QUERY="${ROOT_DIR}/scripts/osc/query-state.sh"

echo "== Cosmic OSC examples =="
echo "Host: ${OSC_HOST:-127.0.0.1}  Port: ${OSC_PORT:-9000}"
if [[ -n "${OSC_TOKEN:-}" ]]; then
  echo "Token: configured"
else
  echo "Token: not set (OSC_TOKEN empty)"
fi
if [[ "${OSC_HOST:-127.0.0.1}" != "127.0.0.1" && -z "${OSC_TOKEN:-}" ]]; then
  echo "WARNING: LAN host without OSC_TOKEN. Enable token for shared networks." >&2
fi

echo
echo "[1/6] Next scene"
"${SEND}" "/cosmic/scene/next"

echo
echo "[2/6] Set manual BPM to 126"
"${SEND}" "/cosmic/tempo/bpm f 126"

echo
echo "[3/6] Tap tempo"
"${SEND}" "/cosmic/tempo/tap"

echo
echo "[4/6] Set fractal zoom to 1.35"
"${SEND}" "/cosmic/fractal/zoom f 1.35"

echo
echo "[5/6] Enable overlay"
"${SEND}" "/cosmic/overlay/enabled f 1"

echo
echo "[6/6] Query current app state"
if ! "${QUERY}"; then
  echo "State query did not return. Verify OSC UDP control is enabled and token/host/port match Settings." >&2
fi

echo
echo "Done."
