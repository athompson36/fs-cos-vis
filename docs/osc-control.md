# OSC Control Quickstart

Cosmic Visualizer supports UDP OSC-style control lines in Settings under **Remote control**.

## Enable OSC

1. Open `Settings`.
2. In **Remote control (HTTP + WebSocket)**, enable **OSC UDP control**.
3. Set port (default `9000`) and optional token.
4. If controlling from another machine, enable **OSC Bind LAN**.

## Supported message format

Messages are newline-free UTF-8 lines sent over UDP.

- command only:
  - `/cosmic/scene/next`
- command with float:
  - `/cosmic/fractal/zoom f 1.25`
- command with int:
  - `/cosmic/lighting/cue/index i 3`
- command with string:
  - `/cosmic/palette/select s 00000000-0000-0000-0000-000000000222`
- with token:
  - `/cosmic/scene/next token=my-secret`

## Common commands

- `/cosmic/scene/next`
- `/cosmic/scene/previous`
- `/cosmic/scene/random`
- `/cosmic/scene/jump <uuid>`
- `/cosmic/tempo/tap`
- `/cosmic/tempo/bpm f 128.0`
- `/cosmic/fractal/zoom f 1.4`
- `/cosmic/liquid/turbulence f 1.2`
- `/cosmic/composite/blend f 0.65`
- `/cosmic/liquid/enabled f 1`
- `/cosmic/overlay/enabled f 1`
- `/cosmic/performance/enabled f 0`
- `/cosmic/palette/select s <uuid>`
- `/cosmic/lighting/cue/index i <index>`

## State query

Send:

- `/cosmic/state/get`

The app replies via UDP to the sender with the same JSON payload used by web `/api/state`.

## Helper script

Use the included helper:

```bash
python3 scripts/osc/osc_control.py --message "/cosmic/scene/next"
python3 scripts/osc/osc_control.py --message "/cosmic/fractal/zoom f 1.3"
python3 scripts/osc/osc_control.py --query-state
python3 scripts/osc/osc_control.py --query-state --token "my-secret"
```

## Shell shortcuts

If you prefer shorter commands, use:

```bash
scripts/osc/send.sh "/cosmic/scene/next"
scripts/osc/send.sh "/cosmic/fractal/zoom f 1.3"
scripts/osc/query-state.sh
scripts/osc/examples.sh
```

Environment overrides:

- `OSC_HOST` (default `127.0.0.1`)
- `OSC_PORT` (default `9000`)
- `OSC_TOKEN` (default empty)
- `OSC_TIMEOUT` (query timeout, default `1.5`)

`scripts/osc/examples.sh` runs a short operator flow: scene advance, BPM set/tap, zoom, overlay toggle, and state query.

## Secure LAN examples (token required)

For shared/Wi-Fi control, set a token in Settings and export it before sending commands:

```bash
export OSC_HOST="192.168.1.50"
export OSC_PORT="9000"
export OSC_TOKEN="my-secret-token"

scripts/osc/send.sh "/cosmic/scene/next"
scripts/osc/send.sh "/cosmic/tempo/bpm f 124"
scripts/osc/query-state.sh
scripts/osc/examples.sh
```

If `OSC_HOST` is not localhost and `OSC_TOKEN` is empty, `scripts/osc/examples.sh` prints a warning.
