# Control surface parity (native / HTTP / MIDI / OSC)

All automation ultimately funnels through `RemoteControlCommand` and `AppModel.applyRemoteCommand(_:)` (main-thread mutations). There is no second “hidden” control plane for scene/layer/tempo actions.

## HTTP — `POST /api/command`

Accepts **any** JSON object decodable as `RemoteControlCommand` (`type` plus optional fields). This is the **most complete** surface: if a command type exists in `applyRemoteCommandOnMainThread`, you can invoke it from scripts or custom web clients.

The bundled remote web UI is driven by `ControlSchema.cosmicDefault()` (`GET /api/schema`), which exposes a **subset** of commands as buttons/sliders plus REST helpers (`GET/PUT /api/scenes`, settings, MIDI mapping, etc.).

## Web schema (`ControlSchema`)

See `FSDMXVision/FSDMXVision/Features/Web/ControlSchema.swift`. Fields map `commandType` strings to `POST /api/command` bodies. Anything not listed there is still available via raw JSON to `POST /api/command`.

**How lighting layers stack (cues vs modulation vs inbound DMX):** [`lighting-control-strategies.md`](lighting-control-strategies.md).

**Detailed diff (schema vs all implemented command types):** [`control-schema-coverage.md`](control-schema-coverage.md).

**Manual smoke (OSC / HTTP / WS):** [`control-plane-smoke.md`](control-plane-smoke.md).

## HTTP — Settings document (`GET` / `PUT /api/settings`)

The body is JSON for **`RemoteControlSettings`** (see `FSDMXVision/FSDMXVision/Features/Control/RemoteControlSettings.swift`, `CodingKeys`). **PUT** replaces the entire document; clients should **GET** first, merge fields, then **PUT** if they only change a subset.

**Inbound DMX (merge with app output)** — field names are **camelCase** in JSON:

| Key | Meaning |
|-----|---------|
| `dmxInboundEnabled` | Accept Art-Net/sACN on the UDP listener. |
| `dmxInboundMode` | `"artnet"` or `"sacn"`. |
| `dmxInboundUniverse` | First wire universe in the inbound range. |
| `dmxInboundUniverseCount` | Contiguous universe count (1…64). |
| `dmxInboundMergeMode` | `"htp"` or `"lpt"`. |
| `dmxInboundOpenDMXEnabled` | Second USB serial path (Open DMX–class RX), separate from DMX **output** path. |
| `dmxInboundOpenDMXPath` | e.g. `/dev/cu.usbserial-…` (must differ from `dmxSerialDevicePath` when output uses that hardware path). |

All other settings (DMX output, OSC, audio, AI, etc.) use the same encoding as the native app’s saved defaults.

## HTTP — Live state (`GET /api/state`, WebSocket snapshots)

**`WebControlStateDTO`** (`FSDMXVision/FSDMXVision/Features/Web/WebControlStateDTO.swift`) includes transport readouts plus optional **inbound** fields for remote dashboards: the same inbound keys as above (as optionals for backward-compatible decoding), **`dmxInboundStatus`** (human-readable summary), and **`dmxInboundTelemetry`** (UDP listener + OpenDMX USB frame counters and running flags). Older JSON payloads without these keys still decode.

## MIDI

Default CC → command mapping lives in `MIDIMapping.default()` (`Features/Expansion/MIDIMapping.swift`):

- **Discrete CC** (channel 0): scene next/previous/random/tap tempo, lighting cue next/previous.
- **Continuous CC**: all `LayerControlParameter` values (fractal zoom, liquid controls, composite bloom/vignette, etc.).

Users can remap in the Controller UI; learned mappings persist via `MIDIMappingStore`.

## OSC (UDP text lines)

Parsed in `OSCControlBusStub.parseCommand` (`Features/Expansion/ControlBus.swift`). Documented operator list: [`osc-control.md`](osc-control.md).

OSC matches **layer** and **transport** commands that MIDI and the web schema cover; settings-only commands (remote port, auth token, DMX path, etc.) are intentionally absent from OSC—use HTTP or the app UI.

## Native-only / limited remote

Some actions are primarily **UI affordances** (menus, window chrome): e.g. `ToggleMainWindowFullscreen` may be sent via `POST /api/command` if desired, but are not in `ControlSchema` or OSC by default.

## Ongoing backlog

- **Feedback relay (client):** Settings supports an optional **HTTPS relay URL** + optional relay bearer (opaque, not a GitHub PAT); the app POSTs JSON `{ title, body, repository, appVersion }`. Hosting a relay that calls the GitHub API with server-side credentials remains a **deployer** concern — see `docs/todo-full-implementation.md` Section J.
- Expand OSC or schema coverage if operators need specific `RemoteControlCommand` types exposed without raw HTTP.
