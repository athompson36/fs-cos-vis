# Show Director Three-Family Adapter Design (SD-M4 Slice 1)

**Status:** Approved in collaborative design review on 2026-07-16
**Scope:** Real visual-scene, palette, and lighting-cue adapters; AppModel-owned runtime engine; three-family acceptance test
**Out of scope:** Backdrop video, overlays, recording, utility actions, OBS, remote protocol, and Guided Setlist UI

## 1. Goal

Connect the Show Director foundation to three existing app systems without weakening actor isolation or timeline ownership:

1. Recall an existing visual scene by stable UUID string.
2. Select an existing palette by stable UUID string.
3. Recall an existing lighting cue by stable UUID string.
4. Execute all three through one `ShowDirectorEngine` cue package.
5. Verify each main-actor mutation before reporting success.
6. Keep one long-lived production engine owned by `AppModel`.

This slice satisfies the first SD-M4 acceptance criterion: one cue package fires actions across at least three endpoint families.

## 2. Constraints

- `ShowDirectorEngine` remains authoritative for timeline state and execution order.
- Adapters do not own authored show data or runtime position.
- Adapters are `Sendable`; app mutations occur on `MainActor`.
- Adapters never call the fire-and-forget `applyRemoteCommand`.
- Adapters depend on narrow endpoint protocols, not the complete `AppModel` API.
- Existing UUID-backed scene, palette, and lighting-cue identities remain unchanged.
- The foundation's five-second timeout, partial-failure behavior, result logging, and duplicate-command handling remain unchanged.
- Real endpoint adapters execute serially in cue document order.

## 3. Architecture

```text
ShowDirectorEngine actor
        |
ShowEndpointAdapter
        |
  +-----+--------------------+
  |                          |
VisualSceneEndpointAdapter   PaletteEndpointAdapter   LightingCueEndpointAdapter
  |                          |                        |
VisualSceneControlling       PaletteControlling       LightingCueControlling
  |                          |                        |
AppModel main-actor implementations / deterministic test fakes
```

### Why narrow protocols

Directly storing `AppModel` in adapters would expose unrelated mutable state and require broad unchecked sendability. Translating through `RemoteControlCommand` would report success before the command's internally scheduled main-actor task completes. Narrow `@MainActor` protocols provide awaitable mutations, explicit verification, and deterministic fakes.

## 4. Typed Action Contract

Existing actions remain backward-compatible:

- `recallVisualScene(id:sceneID:fadeMilliseconds:)`
- `applyPalette(id:paletteID:fadeMilliseconds:)`
- `recallLightingScene(id:sceneID:fadeMilliseconds:)`

Add the explicit lighting-cue case:

```swift
case recallLightingCue(
    id: String,
    cueID: String
)
```

Wire representation:

```json
{
  "id": "action_light_intro",
  "endpoint": "lighting",
  "type": "recallCue",
  "cueId": "00000000-0000-0000-0000-000000000001"
}
```

Rules:

- `cueId` is a UUID string matching `LightingCue.id`.
- `recallLightingScene` continues decoding for existing documents but is not used by this adapter slice.
- Unknown endpoint/type combinations continue failing decode.
- No cue-array index is persisted in Show Director documents.
- Adding `recallCue` is a backward-compatible extension of schema version 1 because existing version-1 documents keep their existing representation and behavior.

## 5. Main-Actor Control Protocols

Each protocol exposes snapshot, validation, mutation, and verification capabilities required by one adapter.

### Visual scene

```swift
@MainActor
protocol VisualSceneControlling: AnyObject, Sendable {
    func visualSceneIDs() -> [UUID]
    func activeVisualSceneID() -> UUID?
    func recallVisualScene(id: UUID) throws
}
```

`AppModel` implementation:

- Reads `sceneManager.scenes`.
- Uses the same synchronous main-actor path as `performJumpToScene`.
- Starts the existing scene transition when target differs.
- Synchronizes the renderer and persists scenes.
- Throws if persistence fails rather than swallowing the error.

### Palette

```swift
@MainActor
protocol PaletteControlling: AnyObject, Sendable {
    func paletteIDs() -> [UUID]
    func activePaletteID() -> UUID?
    func selectPalette(id: UUID) throws
}
```

`AppModel` implementation:

- Reads `palettes`.
- Sets `selectedPaletteID`.
- Synchronizes renderer state.
- Verifies the selected palette exists before mutation.

### Lighting cue

```swift
@MainActor
protocol LightingCueControlling: AnyObject, Sendable {
    func lightingCueIDs() -> [UUID]
    func activeLightingCueID() -> UUID?
    func recallLightingCue(id: UUID) throws
    func lightingCueFadeSeconds(id: UUID) -> Double?
}
```

`AppModel` implementation:

- Reads a consistent lighting-cue snapshot through existing lock discipline.
- Resolves UUID to cue index.
- Calls the existing cue activation path so crossfade, haze-envelope start, and persistence behavior remain intact.
- Verifies `activeCueIndex` resolves to the requested UUID after mutation.

The protocol methods are `@MainActor`, so adapter calls suspend until mutation and verification finish.

`AppModel` declares conformance to all three protocols in `AppModel.swift`, where its private scene, lighting-lock, renderer-sync, and persistence members are accessible. The protocol declarations remain in the Show Director adapter directory.

## 6. Adapter Behavior

All three adapters are actors implementing `ShowEndpointAdapter`, with `nonisolated let endpointKind`. Actor isolation owns each adapter's last-failure health state. Every adapter initializer receives its endpoint controller plus a `ShowDirectorClock` for deterministic health timestamps.

### Shared validation

Validation returns `.invalid(message:)` when:

- The action belongs to another endpoint/action family.
- The target string is not a UUID.
- The target UUID is absent from the corresponding library.

Validation does not mutate app state.

### Shared execution

1. Re-check target validity on `MainActor` to avoid a stale validation/execution race.
2. Apply mutation synchronously on `MainActor`.
3. Read the active target back.
4. Return `executed` only when the read-back UUID matches.
5. Return `failed` with a clear message if mutation throws or verification differs.

Adapter execution result duration remains measured by the engine/fake clock contract. Adapters do not create execution-log entries directly.

### Transition timing policy

This slice uses current app semantics honestly:

- Visual scene starts the app's existing transition. Requested `fadeMs` is advisory.
- Palette selection is immediate. Requested `fadeMs` is advisory.
- Lighting cue uses the cue's persisted `fadeSeconds`.

A valid timing mismatch is not a validation failure. The successful result message states the effective policy:

- Visual: `"Scene recalled; requested fadeMs is advisory and the app transition is active."`
- Palette: `"Palette applied immediately; requested fadeMs is advisory."`
- Lighting: `"Lighting cue recalled using its persisted fade of <seconds>s."`

Zero and nonzero `fadeMs` are both accepted for visual/palette actions.

## 7. Endpoint Health

Health is computed from the current main-actor service snapshot.

### `available`

- Visual: scene library contains at least one scene.
- Palette: palette library contains at least one palette.
- Lighting: cue document contains at least one cue.

### `unavailable`

The corresponding library is empty. Message names the missing resource, for example `"No lighting cues are available."`

### `degraded`

The service/library exists, but the most recent mutation could not be verified or persistence failed. The adapter retains a concise last-failure message until a later successful execution clears it.

### `unsupported`

Reserved for a missing endpoint adapter/service. A registered adapter receiving the wrong typed action returns validation failure, not unsupported.

Health timestamps use an injected clock so tests are deterministic.

## 8. AppModel Runtime Ownership

`AppModel` owns one optional long-lived `ShowDirectorEngine`.

```swift
@Published private(set) var showDirectorRuntimeStatus: ShowDirectorRuntimeStatus
private(set) var showDirectorEngine: ShowDirectorEngine?
```

`ShowDirectorRuntimeStatus` cases:

- `unconfigured`
- `loading`
- `ready`
- `failed(message: String)`

### Configuration lifecycle

- Valid graph load/replacement:
  1. Set status to `loading`.
  2. Create adapters backed by the three main-actor control implementations.
  3. Create one engine with the package root and adapters.
  4. Submit `loadShow` with a generated nonempty command ID.
  5. Install the engine and set `ready` only after the command is accepted.
  6. On failure, clear the engine and set `failed`.
- Legacy package with no Show Director graph:
  - Clear the engine and set `unconfigured`.
- Invalid Show Director graph:
  - Keep authored graph unset, clear the engine, and surface `failed`.
- `replaceShowDirectorGraph` follows the same lifecycle.

Configuration uses a cancellable task. Starting a newer configuration cancels the prior task; only the latest generation may install an engine.

No UI is added in this slice. Future SD-M5 UI consumes the status and engine.

## 9. Files and Responsibilities

Create:

- `Features/ShowDirector/Adapters/ShowDirectorEndpointControls.swift`
  - Three `@MainActor`, `Sendable` control protocols.
- `Features/ShowDirector/Adapters/VisualSceneEndpointAdapter.swift`
- `Features/ShowDirector/Adapters/PaletteEndpointAdapter.swift`
- `Features/ShowDirector/Adapters/LightingCueEndpointAdapter.swift`
- `FSDMXVisionTests/ShowDirectorRealAdapterTests.swift`
- `FSDMXVisionTests/ShowDirectorThreeFamilyAcceptanceTests.swift`

Modify:

- `Features/ShowDirector/Models/EndpointAction.swift`
  - Add `recallLightingCue` and `cueId` coding.
- `Features/ShowDirector/Execution/ShowEndpointAdapter.swift`
  - No behavioral change; concrete adapters use the existing `ShowDirectorClock`.
- `App/AppModel.swift`
  - Conform to the three endpoint protocols; add narrow endpoint methods, long-lived engine, status, and race-safe configuration lifecycle.
- `docs/production-and-show-director-todo.md`
- `docs/07-roadmap.md`

## 10. Testing

### Adapter unit tests

For each adapter:

- Correct typed action validates.
- Wrong action family returns validation failure.
- Malformed UUID returns validation failure.
- Missing UUID target returns validation failure.
- Successful execution mutates and verifies target.
- Verification mismatch returns failed.
- Empty library health is unavailable.
- Nonempty library health is available.
- Failure sets degraded health; later success clears it.
- Timing-policy result message is exact.

### AppModel integration tests

- Loading a graph transitions runtime status `loading -> ready`.
- Legacy package clears engine and yields `unconfigured`.
- Invalid graph clears engine and yields `failed`.
- Two rapid configurations install only the latest engine.
- AppModel visual recall synchronizes scene selection.
- Palette recall updates `selectedPaletteID`.
- Lighting recall resolves UUID and activates the correct cue.

### Three-family acceptance

Build a cue package ordered:

1. `recallVisualScene`
2. `applyPalette`
3. `recallLightingCue`

Run it through the real adapters and `ShowDirectorEngine`, then assert:

- Scene UUID, palette UUID, and lighting-cue UUID all match targets.
- One execution log contains three results in document order.
- All statuses are `executed`.
- Runtime revision increases.
- All three endpoint health snapshots are `available`.

### Regression

- Existing 199 tests remain green.
- Package smoke remains green.
- No real DMX hardware, display, or network is required.

## 11. Acceptance Gate

This slice is complete when:

1. A production `AppModel` runtime engine can load a Show Director graph.
2. One cue package executes visual, palette, and lighting-cue actions through real adapters.
3. Main-actor mutations are verified before success is returned.
4. Timing limitations are surfaced honestly.
5. Endpoint health is useful and deterministic.
6. Partial failure still allows sibling actions to finish.
7. Three ordered results are written to one durable log.
8. Full tests and package smoke pass.

## 12. Deferred SD-M4 Work

- Backdrop video playback and video blackout/opacity/transition.
- Overlay selection/hide-all semantics and stable overlay-card identity.
- Recording start/stop/marker completion semantics.
- Utility house look, intermission, applause, safe-mode, and park ownership.
- Lighting intensity, movement, strobe, kill-strobe, and explicit safety limits.
- Per-action visual/palette fade overrides.
- Real adapters for OBS, camera, MIDI, OSC, and audio routing.
