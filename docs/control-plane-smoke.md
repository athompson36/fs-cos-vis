# Control plane — manual / scripted smoke (Gates 2.2–2.3)

**Purpose:** Repeatable checks for **OSC**, **HTTP** (`GET /api/state`, `POST /api/command`), and **WebSocket** state streaming without a full integration test harness. Run with a **local Release or Debug** build and **Remote control** enabled in Settings.

**Defaults:** HTTP listens on **`127.0.0.1`** unless **Bind LAN** is on; default port **`8765`** (`RemoteControlSettings.remoteControlPort`). OSC default UDP **`9000`** — see [`osc-control.md`](osc-control.md).

**Auth:** If an **auth token** is set, pass **`Authorization: Bearer <token>`** or **`?token=`** on HTTP; OSC uses `token=` on the line per [`osc-control.md`](osc-control.md).

---

## Gate 2.2 — OSC vs web state

Web `/api/state` and OSC **`/cosmic/state/get`** are intended to expose the same JSON snapshot shape (see `AppModel.makeWebStateSnapshotData()` / `WebControlStateDTO`).

**Scripted operator flow (app running):**

```bash
# Scene advance + state query (uses scripts/osc/send.sh + query-state.sh)
bash scripts/osc/examples.sh
```

**Single-shot checks:**

```bash
scripts/osc/query-state.sh
python3 scripts/osc/osc_control.py --query-state
```

Compare a few keys (tempo, scene id, flags) against `curl` HTTP state below. For route coverage, see [`osc-control.md`](osc-control.md) and [`control-schema-coverage.md`](control-schema-coverage.md).

---

## Gate 2.3 — HTTP + WebSocket

### Quick HTTP (optional script)

With remote control **enabled** and token **empty** (or export `REMOTE_TOKEN`):

```bash
export REMOTE_PORT="${REMOTE_PORT:-8765}"
bash scripts/ci/smoke-control-plane.sh
```

### Manual `curl` examples

```bash
PORT=8765
BASE="http://127.0.0.1:${PORT}"

# Liveness (no auth when token empty)
curl -sf "${BASE}/health"

# Schema + state (requires auth if token set in Settings)
curl -sf "${BASE}/api/schema"
curl -sf "${BASE}/api/state"

# Example command (NextScene — JSON uses `type`, see RemoteControlCommand)
curl -sf -X POST "${BASE}/api/command" \
  -H 'Content-Type: application/json' \
  -d '{"type":"NextScene"}'
```

**Error behavior (spot-check):** With a **non-empty** token in Settings, requests **without** `Authorization` / `?token=` should return **401** on protected routes; `/health` remains useful for “is the server socket up?”.

### WebSocket state stream

The server exposes **`GET /ws`** (FlyingFox WebSocket). Connect with a WebSocket client (e.g. **`websocat`**) to **`ws://127.0.0.1:<port>/ws`** and confirm periodic JSON text frames. Token query/Bearer behavior matches your build; verify against Settings if connections fail.

**Light load (optional):** Loop `GET /api/state` or connect one WS client for several minutes during a show rehearsal; watch CPU and log noise — no fixed threshold in-repo.

---

## Gate 2.4 — MIDI

MIDI learn + `MIDIMappingStore` persistence stays **Controller UAT** (manual), not covered here — see [`production-readiness-checklist.md`](production-readiness-checklist.md) Gate 4.
