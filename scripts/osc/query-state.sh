#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

HOST="${OSC_HOST:-127.0.0.1}"
PORT="${OSC_PORT:-9000}"
TOKEN="${OSC_TOKEN:-}"
TIMEOUT="${OSC_TIMEOUT:-1.5}"

python3 "${ROOT_DIR}/scripts/osc/osc_control.py" \
  --host "${HOST}" \
  --port "${PORT}" \
  --token "${TOKEN}" \
  --timeout "${TIMEOUT}" \
  --query-state
