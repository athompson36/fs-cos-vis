# Unified Show Director Architecture

## Layering

```text
SwiftUI Workspaces
        |
ShowDirectorStore
        |
Pure Reducer ---- Validation
        |
ShowDirectorEngine actor
        |
EndpointAdapter protocol
        |
Existing app services: visuals, DMX, video, overlays, recording, protocols
```

## Model Layer

Use Codable, versioned, stable-ID models.

Suggested types:

- `ShowDocument`
- `ShowMetadata`
- `Setlist`
- `SetlistItem`
- `SongScore`
- `SongSection`
- `CuePackage`
- `EndpointAction`
- `PresetReference`
- `RuntimeOverride`
- `ShowRuntimeState`
- `EndpointHealth`
- `ExecutionLogEntry`

## Reducer

The reducer is pure. It accepts current runtime state and a command, then returns new state plus effects to execute.

Commands:

- `loadShow`
- `selectSetlistItem`
- `go`
- `previous`
- `next`
- `hold`
- `resume`
- `repeatSection`
- `jumpToSection`
- `firePresetNow`
- `insertPresetNext`
- `replaceUpcomingCue`
- `undo`
- `park`
- `blackout`
- `restoreSafeLook`
- `endpointHealthChanged`
- `cueExecutionFinished`

The reducer must not call DMX, video, OBS, files, or network APIs.

## Execution Engine

`ShowDirectorEngine` should be an actor or otherwise actor-isolated service.

Responsibilities:

- Serialize cue execution.
- Validate cue IDs and endpoint availability.
- Resolve preset references.
- Dispatch endpoint actions to adapters.
- Apply timeouts where appropriate.
- Coalesce duplicate commands.
- Report partial failures.
- Write execution logs.
- Publish state changes.

## Endpoint Adapter Protocol

Adapters hide app-specific services from the timeline model.

```swift
protocol ShowEndpointAdapter {
    var endpointKind: ShowEndpointKind { get }
    func validate(_ action: EndpointAction, context: ShowExecutionContext) async -> ValidationResult
    func execute(_ action: EndpointAction, context: ShowExecutionContext) async -> EndpointExecutionResult
    func currentHealth() async -> EndpointHealth
}
```

Concrete adapters should wrap existing app services:

- `VisualSceneEndpointAdapter`
- `PaletteEndpointAdapter`
- `LightingEndpointAdapter`
- `BackdropVideoEndpointAdapter`
- `OverlayEndpointAdapter`
- `OBSEndpointAdapter`
- `RecordingEndpointAdapter`
- `UtilityEndpointAdapter`
- `MIDIEndpointAdapter`
- `OSCEndpointAdapter`
- `AudioRoutingEndpointAdapter`

## Persistence

Store show metadata as versioned JSON inside the existing project/package system. Do not scatter required show files across arbitrary user folders.

Recommended package layout:

```text
Show.cosmicshow/
  show-director/
    show.json
    setlists/
    songs/
    presets/
    logs/
  media/
    video/
    images/
    overlays/
```

External media may be referenced, but package validation must warn when files are missing.

## Runtime Authority

The Mac host owns authoritative state. Remotes send semantic commands and receive state events. Remotes do not mutate show files directly during performance unless the host accepts and persists a specific edit command.

## Error Handling

Endpoint action results should support:

- `executed`
- `skipped`
- `unsupported`
- `validationFailed`
- `timedOut`
- `failed`

Partial failure should not destroy the whole show state. The UI should show which endpoint failed and offer park/restore/retry.
