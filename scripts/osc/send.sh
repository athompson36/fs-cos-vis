#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

HOST="${OSC_HOST:-127.0.0.1}"
PORT="${OSC_PORT:-9000}"
TOKEN="${OSC_TOKEN:-}"

if [[ $# -lt 1 ]]; then
  echo "Usage: scripts/osc/send.sh \"/cosmic/scene/next\"" >&2
  echo "   or: scripts/osc/send.sh \"/cosmic/fractal/zoom f 1.2\"" >&2
  exit 2
fi

python3 "${ROOT_DIR}/scripts/osc/osc_control.py" \
  --host "${HOST}" \
  --port "${PORT}" \
  --token "${TOKEN}" \
  --message "$1"
