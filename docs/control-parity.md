# Control surface parity (native / HTTP / MIDI / OSC)

All automation ultimately funnels through `RemoteControlCommand` and `AppModel.applyRemoteCommand(_:)` (main-thread mutations). There is no second “hidden” control plane for scene/layer/tempo actions.

## HTTP — `POST /api/command`

Accepts **any** JSON object decodable as `RemoteControlCommand` (`type` plus optional fields). This is the **most complete** surface: if a command type exists in `applyRemoteCommandOnMainThread`, you can invoke it from scripts or custom web clients.

The bundled remote web UI is driven by `ControlSchema.cosmicDefault()` (`GET /api/schema`), which exposes a **subset** of commands as buttons/sliders plus REST helpers (`GET/PUT /api/scenes`, settings, MIDI mapping, etc.).

## Web schema (`ControlSchema`)

See `CosmicVisualizer/Features/Web/ControlSchema.swift`. Fields map `commandType` strings to `POST /api/command` bodies. Anything not listed there is still available via raw JSON to `POST /api/command`.

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
