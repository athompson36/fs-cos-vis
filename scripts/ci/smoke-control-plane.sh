#!/usr/bin/env bash
# Optional manual smoke: HTTP remote control (Gate 2.3).
# Prerequisites: FSDMXVision running with Remote control ON; port matches REMOTE_PORT (default 8765).
# Does not start the app — use alongside a local run or staging machine.
set -euo pipefail

PORT="${REMOTE_PORT:-8765}"
BASE="${REMOTE_BASE:-http://127.0.0.1:${PORT}}"
TOKEN="${REMOTE_TOKEN:-}"

auth=()
if [[ -n "${TOKEN}" ]]; then
  auth=(-H "Authorization: Bearer ${TOKEN}")
fi

echo "[smoke-control-plane] GET ${BASE}/health"
curl -sfS "${BASE}/health" | head -c 200
echo

echo "[smoke-control-plane] GET ${BASE}/api/schema"
curl -sfS "${auth[@]}" "${BASE}/api/schema" | head -c 400
echo "..."

echo "[smoke-control-plane] GET ${BASE}/api/state"
curl -sfS "${auth[@]}" "${BASE}/api/state" | head -c 400
echo "..."

echo "[smoke-control-plane] POST ${BASE}/api/command (TapTempo — no-op if unsupported in current mode)"
curl -sfS -X POST "${auth[@]}" -H 'Content-Type: application/json' \
  -d '{"type":"TapTempo"}' "${BASE}/api/command"
echo

echo "[smoke-control-plane] OK"
