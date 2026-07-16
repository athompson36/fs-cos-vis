# Unified Show Director — Architecture and Data Model

**Repository:** `athompson36/fs-cos-vis`  
**Implementation posture:** Extend the existing native SwiftUI/Metal macOS beta. Do not rewrite working rendering, lighting, DMX, project packaging, or control-plane subsystems.

## 1. Existing architecture to preserve

The current app already provides:

- `AppModel` as the application-state coordinator
- serializable visualization scenes and scene controls
- lighting cue, backdrop cue, overlay-card, modulation, patch, and stage documents
- project-folder and `.cosmicshow.zip` persistence
- audio analysis, BPM, beat phase, manual/tap/MIDI clock tempo sources
- external fullscreen output and Syphon output
- HTTP, WebSocket, OSC, and MIDI control paths
- DMX output/inbound merge and safety overrides

The Show Director work must compose these systems through focused services. It must not add more unrelated responsibilities to `AppModel`.

## 2. Target module layout

```text
Features/
├── ShowControl/
│   ├── Models/
│   │   ├── ShowTimelineModels.swift
│   │   ├── ShowCueModels.swift
│   │   ├── ShowActionModels.swift
│   │   ├── SetlistModels.swift
│   │   ├── SongScoreModels.swift
│   │   ├── PresetModels.swift
│   │   ├── RuntimeOverrideModels.swift
│   │   └── ExecutionLogModels.swift
│   ├── Runtime/
│   │   ├── ShowDirectorEngine.swift
│   │   ├── ShowStateReducer.swift
│   │   ├── ShowActionExecutor.swift
│   │   ├── CueScheduler.swift
│   │   ├── OverrideStack.swift
│   │   └── ShowClock.swift
│   ├── Adapters/
│   │   ├── LightingActionAdapter.swift
│   │   ├── VisualActionAdapter.swift
│   │   ├── OverlayActionAdapter.swift
│   │   ├── BackdropActionAdapter.swift
│   │   ├── OBSActionAdapter.swift
│   │   └── UtilityActionAdapter.swift
│   ├── Sources/
│   │   ├── TrackEventSource.swift
│   │   ├── TraktorEventAdapter.swift
│   │   ├── MaschineEventAdapter.swift
│   │   ├── ManualCueSource.swift
│   │   ├── MIDIShowControlSource.swift
│   │   └── AudioSectionAssistSource.swift
│   ├── Persistence/
│   │   ├── ShowTimelineStore.swift
│   │   ├── PresetLibraryStore.swift
│   │   └── ShowRunLogStore.swift
│   └── UI/
│       ├── SetlistView.swift
│       ├── ShowOperatorView.swift
│       ├── CueEditorView.swift
│       ├── PresetBrowserView.swift
│       └── EndpointHealthView.swift
├── OBS/
│   ├── OBSWebSocketClient.swift
│   ├── OBSModels.swift
│   └── OBSConnectionSettings.swift
└── Companion/
    ├── CompanionProtocol.swift
    ├── CompanionSessionCoordinator.swift
    └── CompanionStateDTO.swift
```

Companion iOS/watchOS targets can be added after the host protocol is stable. Shared models should live in a Swift package or a shared target when that work starts.

## 3. Typed cue model

Do not continue expanding `LightingCue.bookmarkMetadataByCueID` for behavior. Loose metadata remains useful for labels and overlay substitution, but executable show behavior must be typed and versioned.

```swift
struct ShowCueDocument: Codable, Equatable, Sendable {
    static let currentVersion = 1
    var version: Int
    var cues: [ShowCue]
    var activeCueID: UUID?
}

struct ShowCue: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var songID: UUID?
    var sectionID: UUID?
    var trigger: ShowCueTrigger
    var transition: ShowTransition
    var actions: [ShowAction]
    var safetyClass: ShowSafetyClass
    var tags: [String]
    var notes: String
}
```

`ShowAction` should be an enum with associated typed payloads and explicit Codable support:

```swift
enum ShowAction: Equatable, Sendable {
    case lighting(LightingShowAction)
    case visual(VisualShowAction)
    case palette(PaletteShowAction)
    case backdrop(BackdropShowAction)
    case overlay(OverlayShowAction)
    case obs(OBSShowAction)
    case recording(RecordingShowAction)
    case utility(UtilityShowAction)
    case external(ExternalCommandAction)
}
```

Never use a dictionary of arbitrary strings as the canonical action payload.

## 4. Action endpoint examples

### Lighting

- activate existing `LightingCue` by stable UUID
- set palette reference
- apply intensity scale
- set movement preset
- blackout universe/all
- stop movement
- kill strobe
- haze envelope or haze emergency kill

### Visual

- activate `VisualizationScene` by UUID
- set scene transition and duration
- set or temporarily override palette
- set layer parameter snapshot
- open/close external presentation

### Backdrop

- activate existing backdrop cue
- play project-relative media clip
- loop / pause / seek / stop
- transition type and duration
- video blackout

### Overlay

- show/hide overlay package
- bind runtime metadata
- set timeout
- set layer/z-order
- clear transient overlays

### OBS

- connect/disconnect
- switch program scene
- set source visibility
- trigger transition
- set input mute/volume where enabled
- start/stop recording or streaming
- create chapter/marker where supported

### Utility

- hold timeline
- resume timeline
- park
- restore previous state
- add execution marker
- send MIDI/OSC/HTTP command to an external endpoint

## 5. Setlist and song-score models

```swift
struct SetlistDocument: Codable, Equatable, Sendable {
    static let currentVersion = 1
    var version: Int
    var entries: [SetlistEntry]
}

struct SetlistEntry: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var kind: SetlistEntryKind
    var title: String
    var songScoreID: UUID?
    var notes: String
}

struct SongScore: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var identity: SongIdentity
    var tempo: SongTempoMetadata
    var sections: [SongSection]
    var defaultPresetID: UUID?
}

struct SongSection: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var kind: SongSectionKind
    var start: MusicalPosition?
    var duration: MusicalDuration?
    var cueIDs: [UUID]
}
```

Musical positions must support both time and beat-domain representation:

- seconds from start
- beat index
- bar and beat
- phrase index
- external marker ID

Store the authored source and confidence so inferred positions are not presented as exact.

## 6. Runtime state and reducer

Use a deterministic reducer so every control surface sees the same state.

```swift
struct ShowRuntimeState: Equatable, Sendable {
    var mode: ShowRunMode
    var revisionID: UUID
    var runID: UUID
    var currentEntryID: UUID?
    var currentSectionID: UUID?
    var activeCueID: UUID?
    var nextCueID: UUID?
    var held: Bool
    var parked: Bool
    var runtimeOverrides: [RuntimeOverride]
    var stateVersion: UInt64
}
```

`ShowStateReducer` accepts semantic events and returns a new state plus effects:

```text
ShowEvent + Current State -> New State + [ShowEffect]
```

Events include:

- go
- previous
- next
- hold
- resume
- jump
- undo
- fire preset
- insert preset next
- replace upcoming
- track identified
- transport changed
- section entered
- endpoint result

The reducer itself must not call DMX, OBS, or rendering APIs.

## 7. Execution engine

`ShowDirectorEngine` responsibilities:

- serialize cue execution
- create a command ID
- validate safety and dependencies
- resolve references to current project assets
- expand cue package actions
- execute adapters in a defined order
- collect results and warnings
- update runtime state only through the reducer
- append execution log
- expose state snapshots

Recommended action order:

1. safety preconditions
2. metadata/state preparation
3. visual/backdrop preloads
4. lighting/visual/overlay activation
5. OBS switching
6. recording/markers/external actions
7. result acknowledgement

Actions need policies:

- `required`: failure fails the cue
- `bestEffort`: failure warns but cue continues
- `deferred`: queue until endpoint reconnects, only when safe

## 8. Existing subsystem adapters

### Lighting adapter

Call existing `AppModel` APIs such as `setActiveLightingCueIndex`, but migrate toward UUID-based methods. Never manipulate raw DMX arrays from Show Director UI.

### Visual adapter

Use `SceneManager` and existing scene transition code. Add a stable public method for activating by UUID with transition options.

### Backdrop adapter

Use `BackdropCueDocument` and `applyBackdropCueIndex`, moving toward ID-based activation. Extend the backdrop subsystem for video assets instead of putting AVPlayer code into Setlist views.

### Overlay adapter

Use `OverlayCardDocument`, metadata substitution, and activation timestamps. Add named overlay packages if multiple cards must be addressable independently.

### OBS adapter

OBS is an external endpoint. Implement an isolated WebSocket client with reconnect, authentication, request/response correlation, and capability discovery. Do not put OBS protocol handling in `AppModel` or views.

## 9. Control protocol extension

The existing `RemoteControlCommand` is a flat DTO optimized for basic commands. Preserve backward compatibility, but add a versioned semantic envelope for Show Director:

```swift
struct ShowControlEnvelope: Codable, Equatable, Sendable {
    var protocolVersion: Int
    var commandID: UUID
    var clientID: UUID
    var sequence: UInt64
    var sentAt: Date
    var expectedStateVersion: UInt64?
    var command: ShowControlCommand
}
```

Commands:

- `getState`
- `go`
- `previous`
- `next`
- `hold`
- `resume`
- `undo`
- `park`
- `jumpToCue(UUID)`
- `jumpToSection(UUID)`
- `firePreset(UUID)`
- `insertPresetNext(UUID)`
- `replaceUpcomingWithPreset(UUID)`
- `setRunMode(ShowRunMode)`

Responses must return:

- command ID
- accepted/rejected
- current state version
- resulting active/next cue
- warnings
- endpoint results where appropriate

Legacy `/api/command` remains supported. Add `/api/v2/show/*` rather than breaking current clients.

## 10. Track-source adapter boundary

```swift
protocol TrackEventSource: AnyObject {
    var status: TrackSourceStatus { get }
    var onEvent: (@Sendable (NormalizedTrackEvent) -> Void)? { get set }
    func start()
    func stop()
}
```

The core must not assume Traktor exposes a particular API. Build adapters around available mechanisms:

- MIDI clock and transport
- OSC/MIDI commands produced by mappings or bridge software
- file/library identity selected by operator
- optional companion bridge
- audio analysis fallback

A future Ableton Link integration belongs behind the tempo/transport source interface, not in cue models.

## 11. Audio routing boundary

The current `AudioEngine` can capture a selected Core Audio input and forward to a selected output. It is not a general application-to-application patch bay.

For Maschine -> Traktor routing:

- Phase 1: detect and configure an installed virtual audio device, present a musical routing preset, and validate channels.
- Phase 2: manage Core Audio aggregate/multi-output device configuration where public APIs and permissions allow.
- Do not claim the app can create a virtual audio driver without shipping a signed system audio driver.

Create `AudioRoutingCoordinator` separate from `AudioEngine`. `AudioEngine` remains analysis/capture focused.

## 12. Project package changes

Add these versioned files to `ShowProjectPackage`:

```text
setlist.json
song_scores.json
show_cues.json
show_presets.json
show_settings.json
```

Add optional run artifacts:

```text
Artifacts/Runs/<run-id>/execution-log.jsonl
Artifacts/Runs/<run-id>/runtime-overrides.json
Artifacts/Runs/<run-id>/timing-observations.json
```

Media layout:

```text
Media/
├── Video/
├── Overlays/
├── Images/
├── Audio/
└── Thumbnails/
```

All new decoders must provide defaults for older packages. Add migration tests.

## 13. UI integration

Add **Setlist** as a primary tab between Live Show and Scene Studio, or adopt the documented sidebar navigation spike when the number of top-level surfaces becomes unwieldy.

Keep responsibilities clear:

- Live Show: visuals/performance preview and quick actions
- Setlist: show order, current/next cue, GO and runtime overrides
- Scene Studio: visual authoring
- Lighting: patch, lighting cue authoring, stage, verification
- Controller: MIDI/OSC control mapping
- Settings: endpoint configuration

Do not turn Setlist into another dense authoring screen. Editing can use sheets or a separate editor mode.

## 14. Concurrency rules

- UI-observable state publishes on `MainActor`.
- network, media, and endpoint work run off the main actor.
- cue execution is serialized through one actor.
- adapter completion results are immutable Sendable values.
- never hold `lightingDMXLock` while awaiting async work.
- no per-frame Task creation in render callbacks.

## 15. Testing strategy

Required pure/deterministic tests:

- Codable migration for every new document
- reducer transitions
- GO/hold/resume/undo/park
- runtime override precedence
- action ordering and required/best-effort failure policy
- idempotent duplicate command handling
- sequence/state-version conflict behavior
- old show-package compatibility
- song section timing conversion
- track identity matching confidence

Adapter tests use fakes:

- fake lighting adapter
- fake visual adapter
- fake OBS adapter
- fake clock
- fake track event source

Integration smoke:

- create show -> save -> archive -> import -> run cue
- fire same cue through native and HTTP v2 paths
- disconnect/reconnect companion and resync
- OBS unavailable while lighting/visual best-effort cue continues

Hardware/field tests remain separate and documented.
