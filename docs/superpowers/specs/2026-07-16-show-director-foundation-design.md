# Show Director Foundation Design (SD-M0–M3)

**Status:** Approved in collaborative design review on 2026-07-16
**Scope:** Persistence, typed models, validation, pure reducer, actor execution engine, fake adapters, and durable logs
**Out of scope:** Real endpoint adapters, SwiftUI workspace, remote protocol v2, companion apps, backdrop video playback, OBS, DJ integrations, and assisted automation

## 1. Goal

Build a deterministic, endpoint-neutral Show Director foundation that can:

1. Load and save a versioned show graph inside an existing FS DMX Vision show package.
2. Reject structurally invalid graphs while warning about unavailable media.
3. Reduce semantic operator commands into authoritative runtime state plus declarative effects.
4. Serialize and execute effects through fake endpoint adapters.
5. Preserve partial-failure evidence in a durable execution log.
6. Publish monotonically revised runtime state for later UI and remote clients.

The foundation must not alter the existing visualization, DMX, scene, or package behavior when no Show Director data exists.

## 2. Design Principles

- The Mac host is authoritative.
- Persisted IDs are stable, non-empty `String` values. Decoding never invents replacement IDs.
- Persisted JSON is versioned. Unknown future schema versions fail with a useful error.
- Domain models are Foundation-only and have no dependency on SwiftUI, `AppModel`, DMX, video, OBS, files, sockets, or clocks.
- The reducer is pure and deterministic.
- Endpoint I/O occurs only inside `ShowDirectorEngine`, an actor.
- Adapter failure is isolated per action; one failure does not prevent sibling actions from completing.
- Existing package files and the existing uppercase `Media/` directory remain compatible.
- Required graph failures are errors. Missing package media is a warning.
- Real endpoint adapters are deferred to SD-M4.

## 3. Layering

```text
Existing show package
        |
ShowDirectorPackageStore
        |
Typed domain graph ---- ShowDirectorValidator
        |
ShowDirectorReducer (pure)
        |
ShowDirectorEngine actor
        |
ShowEndpointAdapter protocol
        |
Fake adapters (SD-M3)
```

### Boundary responsibilities

**`ShowDirectorPackageStore`**

- Owns package-relative paths and directory creation.
- Loads, migrates, validates, stages, and atomically replaces Show Director documents.
- Resolves package-relative media paths without allowing paths to escape the package.
- Treats absence of `show-director/` as a valid legacy package with no Show Director document.

**Domain and validation**

- Define the persisted graph, runtime state, commands, effects, results, and validation issues.
- Know nothing about disk paths beyond persisted relative media-reference strings.

**`ShowDirectorReducer`**

- Accepts current reducer state plus one command.
- Returns a new reducer state and zero or more declarative effects.
- Performs no I/O and reads no ambient time.

**`ShowDirectorEngine`**

- Serializes command handling.
- Deduplicates command IDs.
- Runs reducer effects through adapters.
- Applies action timeouts.
- Reports each action result to the reducer.
- Appends durable log entries and publishes runtime state.

## 4. Package Layout

Show Director extends the current package identified by root `project.json`.

```text
show-package/
  project.json
  scenes.json
  scene_controls.json
  dmx_patch.json
  lighting_cues.json
  backdrop_cues.json
  modulation.json
  stage_layout.json
  overlay_cards.json
  Media/
    video/
    images/
    overlays/
  show-director/
    show.json
    setlists/
      <setlist-id>.json
    songs/
      <song-id>.json
    cue-packages/
      <cue-package-id>.json
    presets/
      <preset-id>.json
    logs/
      execution.jsonl
```

### Layout rules

- `show.json` is an index, not an embedded copy of the graph.
- Setlists, songs, cue packages, and presets use one JSON file per stable ID.
- Stable IDs must match `^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$` and may not equal `.` or `..`.
- The filename is the stable ID plus `.json`; no additional escaping or normalization is applied.
- Existing `Media/` casing is retained. No second lowercase `media/` root is created.
- Media references are package-relative paths beginning with `Media/`.
- Logs are append-only JSON Lines. They are not required to reconstruct authoritative runtime state.
- Package archives continue to include the complete package through the existing `ditto` path.

### Atomic save policy

1. Encode the complete Show Director graph into a sibling staging directory.
2. Validate the encoded staging graph by loading it back.
3. Move the existing `show-director/` directory to a temporary backup.
4. Atomically move staging into `show-director/`.
5. Remove the temporary backup after success.
6. Restore the backup if replacement fails.

Individual JSON files also use atomic writes. The package store never leaves a mixture of old and new Show Director documents after a handled save failure.

## 5. Persisted Domain Model

All persisted root documents use `schemaVersion: Int`. Version 1 is the initial supported schema.

### JSON spelling policy

The wire format keeps the lower-camel-case spellings from `show-control-json-examples.md`, even where Swift uses the `ID` abbreviation:

- `defaultSetlistID` encodes as `defaultSetlistId`.
- `setlistIDs`, `songIDs`, `cuePackageIDs`, and `presetIDs` encode as `setlistIds`, `songIds`, `cuePackageIds`, and `presetIds`.
- `songScoreID`, `cuePackageID`, `presetID`, `sceneID`, `paletteID`, `clipID`, `overlayID`, and `commandID` encode with an `Id` suffix.
- `musicalKey` encodes as `key`.
- `fadeMilliseconds` and result durations encode as `fadeMs` and `durationMs`.

Models use explicit `CodingKeys` or custom `Codable`; they do not rely on automatic acronym spelling.

### `ShowDocument`

```swift
struct ShowDocument: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1
    var schemaVersion: Int
    var id: String
    var metadata: ShowDirectorMetadata
    var defaultSetlistID: String
    var setlistIDs: [String]
    var songIDs: [String]
    var cuePackageIDs: [String]
    var presetIDs: [String]
}
```

`ShowDirectorMetadata` avoids collision with the existing root-package `ShowMetadata`.

```swift
struct ShowDirectorMetadata: Codable, Equatable, Sendable {
    var name: String
    var artist: String?
    var notes: String?
}
```

### Setlists and songs

```swift
struct Setlist: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var id: String
    var name: String
    var items: [SetlistItem]
}

struct SetlistItem: Codable, Equatable, Sendable {
    var id: String
    var songScoreID: String
    var label: String
}

struct SongScore: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var id: String
    var artist: String
    var title: String
    var bpm: Double?
    var musicalKey: String?
    var sections: [SongSection]
}

struct SongSection: Codable, Equatable, Sendable {
    var id: String
    var name: String
    var type: SongSectionType
    var cuePackageID: String
}
```

`SongSectionType` cases:

`intro`, `verse`, `chorus`, `solo`, `breakdown`, `drop`, `outro`, `applause`, `intermission`, and `custom`.

### Cue packages and actions

```swift
struct CuePackage: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var id: String
    var name: String
    var actions: [EndpointAction]
}
```

`EndpointAction` is a typed enum with associated payloads and custom `Codable`. Version 1 recognizes:

- `recallLightingScene(id:sceneID:fadeMilliseconds:)`
- `applyPalette(id:paletteID:fadeMilliseconds:)`
- `playBackdropClip(id:clipID:transition:loop:)`
- `addOBSMarker(id:label:)`
- `recallVisualScene(id:sceneID:fadeMilliseconds:)`
- `showOverlay(id:overlayID:)`
- `hideAllOverlays(id:)`
- `startRecording(id:namingTemplate:)`
- `stopRecording(id:)`
- `blackoutLighting(id:)`
- `blackoutVideo(id:)`
- `restoreSafeLook(id:)`

The wire representation retains the documented keys `id`, `endpoint`, and `type`, with case-specific payload keys. Unknown endpoint/action combinations fail decoding as an unsupported version-1 action. They are not stored as arbitrary dictionaries.

`ShowEndpointKind` cases:

`lighting`, `palette`, `visuals`, `backdropVideo`, `overlay`, `obs`, `camera`, `recording`, `utility`, `midi`, `osc`, and `audioRouting`.

Known endpoint kinds may have no version-1 action case yet. Their adapters report `unsupported` only for a known typed action that they cannot execute; unrecognized JSON never becomes an executable action.

### Presets

```swift
struct ShowPreset: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var id: String
    var name: String
    var cuePackageID: String
}

struct PresetReference: Codable, Equatable, Sendable {
    var presetID: String
    var label: String?
}
```

A preset is a reusable reference to one cue package. It does not duplicate cue actions.

### In-memory aggregate

The package store resolves split files into one immutable aggregate:

```swift
struct ShowDirectorGraph: Equatable, Sendable {
    var show: ShowDocument
    var setlistsByID: [String: Setlist]
    var songsByID: [String: SongScore]
    var cuePackagesByID: [String: CuePackage]
    var presetsByID: [String: ShowPreset]
}
```

The dictionaries are derived from decoded arrays/files only after duplicate-ID checks. Encoding writes values in stable ID sort order. `ShowDirectorGraph` itself is not encoded as one JSON document.

## 6. Runtime Model

Runtime state is authoritative in memory and Codable for state snapshots and future remote transport. It is not silently written back to the authored show graph.

```swift
struct ShowRuntimeState: Codable, Equatable, Sendable {
    var revision: UInt64
    var showID: String?
    var activeSetlistID: String?
    var activeSetlistItemID: String?
    var activeSongID: String?
    var activeSectionID: String?
    var transport: ShowTransportState
    var pendingCuePackageID: String?
    var activeOverrides: [RuntimeOverride]
    var endpointHealth: [EndpointHealth]
    var lastCommandID: String?
}
```

`ShowTransportState` is `unloaded`, `ready`, `running`, `held`, or `parked`.

```swift
struct RuntimeOverride: Codable, Equatable, Sendable {
    var id: String
    var presetID: String
    var placement: RuntimeOverridePlacement
    var createdByCommandID: String
}
```

`RuntimeOverridePlacement` is `fireNow`, `insertNext`, or `replaceUpcoming`.

```swift
struct EndpointHealth: Codable, Equatable, Sendable {
    var endpoint: ShowEndpointKind
    var status: EndpointHealthStatus
    var message: String?
    var observedAt: Date
}
```

`EndpointHealthStatus` is `available`, `degraded`, `unavailable`, or `unsupported`.

`ShowDirectorReducerState` wraps `ShowRuntimeState`, the loaded validated graph, the queued override, and a bounded undo history. Version 1 retains at most 20 runtime snapshots. Undo history is runtime-only and is not part of authored show JSON.

## 7. Validation and Migration

### Structured issues

```swift
struct ShowDirectorValidationIssue: Codable, Equatable, Sendable {
    var severity: ShowDirectorValidationSeverity
    var code: String
    var path: String
    var message: String
}
```

Severity is `warning` or `error`. Validation returns all detectable issues in deterministic path/code order.

### Errors

- Missing or invalid stable IDs.
- Duplicate IDs within any entity collection.
- Duplicate setlist-item, song-section, or action IDs.
- `defaultSetlistID` absent from `setlistIDs`.
- Index IDs without corresponding files.
- Extra files whose document IDs are not indexed.
- Setlist items referencing missing songs.
- Song sections referencing missing cue packages.
- Presets referencing missing cue packages.
- Unsupported version-1 endpoint/action combinations.
- Media paths that are absolute or escape the package.
- Unsupported future `schemaVersion`.

### Warnings

- Referenced package media is absent.
- A known endpoint kind has no registered adapter.
- Optional BPM or musical-key metadata is absent.

Warnings do not prevent loading or execution. Errors prevent the new graph from replacing the currently loaded graph.

### Migration

`ShowDirectorMigrator` exposes one entry point:

```swift
static func migrateDocumentData(
    _ data: Data,
    kind: ShowDirectorDocumentKind
) throws -> Data
```

Version 1 passes through after schema verification. A version lower than current is migrated one version at a time when a future migration exists. A version greater than current throws `unsupportedFutureSchemaVersion`. Migration is deterministic and idempotent.

## 8. Commands, Reducer, and Effects

Every external command carries a non-empty `commandID`. Reducer-only engine feedback commands carry the originating command ID.

`ShowDirectorCommand` cases:

- `loadShow(commandID:graph:)`
- `selectSetlistItem(commandID:itemID:)`
- `go(commandID:)`
- `previous(commandID:)`
- `next(commandID:)`
- `hold(commandID:)`
- `resume(commandID:)`
- `repeatSection(commandID:)`
- `jumpToSection(commandID:sectionID:)`
- `firePresetNow(commandID:presetID:)`
- `insertPresetNext(commandID:presetID:)`
- `replaceUpcomingCue(commandID:presetID:)`
- `undo(commandID:)`
- `park(commandID:)`
- `blackoutLighting(commandID:)`
- `blackoutVideo(commandID:)`
- `restoreSafeLook(commandID:)`
- `endpointHealthChanged(commandID:health:)`
- `cueExecutionFinished(commandID:cuePackageID:results:)`

Live-band commands such as skip-song and insert-encore are deliberately deferred until after SD-M3.

`ShowDirectorEffect` cases:

- `executeCuePackage(commandID:cuePackageID:)`
- `executeSafetyAction(commandID:action:)`
- `publishState`

Durable logging is an engine responsibility after effect execution, not an effect emitted by the pure reducer. This prevents duplicate log effects when engine feedback is reduced.

### Reducer rules

- `loadShow` sets the default setlist and first item/section, then enters `ready`.
- `go` from `ready` or `running` executes the current or next section cue respectively.
- `go` while `held` emits no execution effect and preserves position.
- `hold` preserves position and enters `held`.
- `resume` returns to `running` without automatically firing a cue.
- `previous`, `next`, and `jumpToSection` remain within the active song/setlist graph.
- `repeatSection` schedules the current section cue without changing position.
- `firePresetNow` executes immediately.
- `insertPresetNext` queues one override after the current cue.
- `replaceUpcomingCue` substitutes one upcoming cue without changing the authored show.
- `undo` restores the most recent runtime snapshot and emits any required target-restoration effect only when representable by a known cue package or safety action.
- `park`, `blackoutLighting`, `blackoutVideo`, and `restoreSafeLook` remain distinct safety operations.
- Every accepted state-changing command increments `revision` exactly once.
- Rejected/no-op commands return a typed rejection reason and do not increment `revision`.

The reducer API returns:

```swift
struct ShowDirectorReduction: Equatable, Sendable {
    var state: ShowDirectorReducerState
    var effects: [ShowDirectorEffect]
    var disposition: ShowDirectorCommandDisposition
}
```

## 9. Engine and Adapter Contract

```swift
protocol ShowEndpointAdapter: Sendable {
    var endpointKind: ShowEndpointKind { get }
    func validate(
        _ action: EndpointAction,
        context: ShowExecutionContext
    ) async -> ShowActionValidationResult
    func execute(
        _ action: EndpointAction,
        context: ShowExecutionContext
    ) async -> EndpointExecutionResult
    func currentHealth() async -> EndpointHealth
}
```

Execution result status is:

`executed`, `skipped`, `unsupported`, `validationFailed`, `timedOut`, or `failed`.

### Engine behavior

- The actor owns reducer state, adapter registry, processed-command cache, clock, log writer, and state stream continuations.
- `submit(_:)` is the single external command entry point.
- Commands are processed in actor order.
- A repeated `commandID` returns the cached disposition and does not execute effects again.
- The processed-command cache retains the latest 512 IDs.
- Cue actions preserve document order for deterministic logs. Independent action execution may be parallelized only in a later schema version with explicit ordering semantics.
- Each action receives a configurable timeout; version-1 default is 5 seconds.
- Missing adapter produces `unsupported`.
- Adapter validation failure produces `validationFailed` without calling `execute`.
- Timeout or failure affects only that action.
- After all action results are collected, the engine reduces `cueExecutionFinished`, appends one execution log entry, and publishes the resulting state.
- Runtime revisions are monotonically increasing.

The state publisher is an `AsyncStream<ShowRuntimeState>`. The initial current state is yielded immediately to each subscriber.

### Fake adapters

`FakeShowEndpointAdapter` supports deterministic scripted validation results, execution results, delays through an injected clock, invocation capture, and health values. It is test-only and provides no real service wiring.

## 10. Execution Logging

Each completed cue or safety action writes one `ExecutionLogEntry` containing:

- Stable log ID supplied by an injected ID generator.
- Timestamp supplied by an injected clock.
- Command ID.
- Cue package ID when applicable.
- Ordered action results.
- Runtime revision before and after completion.

The log writer appends one sorted-key JSON object plus newline to `show-director/logs/execution.jsonl`. A malformed final partial line is ignored on read and reported as a warning; earlier malformed lines are errors.

Logs never contain API keys, tokens, full prompts, or arbitrary endpoint secrets.

## 11. Existing-App Integration

- `ShowProjectPackage` remains the package marker/archive authority.
- `ShowDirectorPackageStore` is called after the existing package payloads are saved.
- `AppModel` holds an optional loaded Show Director graph/runtime owner; packages without `show-director/` set it to `nil`.
- Load decodes and validates the complete Show Director graph before replacing the currently loaded graph.
- A Show Director load error must not partially mutate Show Director runtime state.
- Existing root JSON formats, `Media/`, archive naming, and legacy package behavior remain unchanged.
- No Show Director UI is added in this scope.

## 12. Testing Strategy

### Models and migration

- Round-trip every version-1 root document.
- Decode canonical examples adapted to split-file `show.json`.
- Prove stable IDs survive encode/decode unchanged.
- Reject empty IDs and unknown future versions.
- Prove migration pass-through is idempotent.

### Validation

- Duplicate IDs produce deterministic paths and codes.
- Missing song, cue-package, and preset references are errors.
- Missing media is a warning and does not block graph loading.
- Absolute and package-escaping media paths are errors.
- Unknown action types fail with a useful decoding error.

### Package store

- Save/load a complete graph.
- Preserve a legacy package without `show-director/`.
- Create `Media/video`, `Media/images`, and `Media/overlays`.
- Roll back after an injected replacement failure.
- Archive export/import preserves Show Director files.
- Reject mismatched filename/document IDs.

### Reducer

- Table-driven tests cover every command and transport state.
- GO/hold/resume/repeat/jump/previous/next remain deterministic.
- Undo restores the previous runtime snapshot.
- Manual overrides do not mutate the authored graph.
- Lighting and video blackout remain separate.
- Reducer source imports no endpoint service.

### Engine

- Concurrent submissions execute serially.
- Repeated command IDs execute once.
- Action order is deterministic.
- Timeout and partial failure are logged per action.
- One failed action does not block sibling actions.
- State revisions increase monotonically.
- Every subscriber receives current and subsequent state.

### Regression

- Existing package and archive tests remain green.
- The full macOS unit suite remains green.
- No changes are required to renderer, DMX, audio, or existing scene tests.

## 13. Documentation and Agent Guidance

- Copy the context pack's Show Director rule into the live `.cursor/rules/` directory and reconcile it with existing project rules.
- Treat the root `README.md`, `docs/project-audit-and-feature-status.md`, `docs/07-roadmap.md`, and `docs/production-and-show-director-todo.md` as the live source-of-truth chain.
- Mark context-pack copies of roadmap/audit documents as reference inputs rather than competing live status documents.
- Update SD-M0 through SD-M3 checkboxes only after their acceptance tests pass.
- Document the final package tree and schema-version policy in the release/package documentation.

## 14. Acceptance Gate

SD-M0–M3 is complete when a versioned demo show:

1. Saves into and loads from the approved split package layout.
2. Validates with no structural errors.
3. Advances through multiple sections using deterministic GO, hold, resume, jump, repeat, and undo behavior.
4. Dispatches cue actions through the actor engine to fake adapters.
5. Survives one timed-out action while completing and logging sibling actions.
6. Appends a durable execution-log entry.
7. Publishes the final authoritative runtime state with a higher revision.
8. Leaves all existing project-package and application tests passing.
9. Has one canonical live documentation path and an active Show Director Cursor rule.

## 15. Deferred Work

- Real visual, palette, lighting, backdrop-video, overlay, recording, utility, OBS, camera, MIDI/OSC, and audio-routing adapters.
- Guided Setlist UI and execution-log UI.
- Remote protocol v2 and command revision conflict handling over HTTP/WebSocket.
- iPhone and Apple Watch clients.
- Backdrop video playback.
- DJ/live-electronic integrations.
- Live-band skip-song, announcement, and encore insertion commands.
- Parallel endpoint execution semantics.
- Editing or persisting runtime overrides into authored show files.
