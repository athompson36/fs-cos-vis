# Unified Show Director — Integration Contracts

**Purpose:** Define honest implementation boundaries for Traktor, Maschine, OBS, audio routing, iPhone, Apple Watch, MIDI, OSC, and web control.

## 1. Integration rule

The Show Director core consumes normalized semantic events and emits typed show actions. Vendor-specific code lives in adapters. No vendor protocol should leak into setlist, song-score, or cue models.

```text
Vendor / Device -> Adapter -> Normalized Event -> Show Director
Show Director -> Typed Action -> Endpoint Adapter -> Vendor / Device
```

Every adapter publishes:

- connection status
- capabilities
- last event/result time
- confidence where inference is involved
- recoverable error text

## 2. Traktor Pro integration

### 2.1 Desired data

The ideal Traktor source would provide:

- deck identifier
- loaded track stable ID or file identity
- artist/title
- deck transport state
- deck/master/on-air state
- BPM
- beat phase
- bar/phrase position
- current loop/cue or Remix Deck event
- section marker

Do not assume all of this is available from one supported Traktor API.

### 2.2 Progressive integration levels

#### Level A — Manual identity + MIDI clock

- Operator selects the active song score.
- Traktor sends MIDI clock/transport through an available MIDI route.
- Show Director follows tempo and beat phase.
- Section changes remain manual or timed.

This is the first reliable implementation target.

#### Level B — Mapped semantic commands

Use Traktor controller mappings, bridge software, or a companion utility to send commands such as:

```text
/cosmic/show/song/select <song-id>
/cosmic/show/section/enter <section-id>
/cosmic/show/go
/cosmic/show/track/deck A
```

The bridge may use MIDI notes/CCs, OSC, or HTTP. The Mac app only sees normalized commands.

#### Level C — Library/file matching

If a bridge can expose a track path or metadata, match against `SongIdentity` using:

1. stable external ID,
2. canonical file URL/bookmark,
3. audio/content fingerprint,
4. normalized artist + title + duration,
5. operator confirmation.

Store match method and confidence.

#### Level D — Audio inference fallback

Use current audio BPM/features and future structure inference only when deterministic metadata is unavailable. Inferred song/section state must be labeled and must not silently trigger high-risk actions unless explicitly authorized.

### 2.3 Ableton Link

Treat Ableton Link as a future tempo/phase source behind a protocol such as:

```swift
protocol MusicalClockSource: AnyObject {
    var status: MusicalClockStatus { get }
    var onTick: (@Sendable (MusicalClockSnapshot) -> Void)? { get set }
    func start()
    func stop()
}
```

Do not embed Link types in `SongScore` or `ShowCue`.

### 2.4 Remix Deck and controller events

Potential events from F1/S5/S2 mappings:

- GO / hold / undo / park
- fire preset by bank/pad
- activate lighting cue
- activate visual scene
- palette next/previous
- section enter
- Remix cell category event: drums, bass, vocal, FX, atmosphere

Map musical categories to semantic events, not hard-coded DMX channels.

## 3. Maschine integration

### 3.1 Tempo

Maschine can share tempo with the performance environment through the best available transport mechanism. Show Director should consume a normalized clock, not decide which application is master in core code.

### 3.2 Performance events

Useful normalized events:

- project loaded
- scene selected
- pattern launched
- group selected/muted
- macro changed
- pad/note category event
- transport start/stop

First implementation should accept MIDI/OSC events generated from an explicit Maschine mapping or bridge. Do not build against undocumented internals.

Example mapping:

```text
Maschine Group A scene -> show event `instrument.drums`
Maschine Group B scene -> show event `instrument.bass`
Macro 1 threshold crossing -> fire visual accent preset
Pattern change -> enter song section
```

All mapping is user-editable and project-scoped.

## 4. Audio routing

### 4.1 Current app capability

The existing audio engine:

- selects a Core Audio input device,
- analyzes audio,
- can forward selected input to an output device for capture.

It does not create an inter-application virtual audio device.

### 4.2 Target routing workflow

For Maschine into a Traktor Live Input deck:

```text
Maschine output
    -> installed virtual audio device channels
    -> Traktor Live Input deck
    -> S5 mixer/master output
```

Show Director can provide a routing coordinator that:

- detects devices and channel counts,
- stores named routing intent,
- verifies sample rates,
- tests signal presence,
- warns about feedback loops,
- explains required application settings,
- optionally manages supported Aggregate/Multi-Output configurations.

### 4.3 Hard boundary

Do not state that the app provides virtual audio routing unless it includes and distributes an appropriate signed macOS audio driver. Phase 1 depends on an installed virtual device or physical loopback.

### 4.4 Routing presets

Recommended presets:

- **DJ only:** Traktor -> S5 output
- **DJ + Maschine:** Maschine -> virtual pair -> Traktor Deck D -> S5 output
- **Show capture:** Traktor master + microphone/reference -> recording/OBS paths
- **Studio rehearsal:** Maschine and Traktor routed to a DAW/capture device as explicitly configured

Persist device UIDs and semantic channel names, but revalidate on every launch.

## 5. OBS integration

### 5.1 Existing relationship

FS DMX Vision already publishes Syphon output and can record its own output. OBS control is a separate external integration.

### 5.2 Adapter responsibilities

`OBSWebSocketClient` must own:

- connection URL and authentication
- protocol negotiation/capability discovery
- reconnect with bounded backoff
- request IDs and response correlation
- event subscription
- current program/preview scene cache
- explicit errors surfaced to endpoint health

### 5.3 Typed actions

Minimum actions:

- set current program scene
- set preview scene when supported
- trigger studio-mode transition
- set source visibility
- set input mute
- start/stop recording
- start/stop streaming only with explicit enablement
- save replay buffer when supported
- create marker/chapter through the best supported mechanism

### 5.4 Failure policy

Each OBS action declares whether it is required or best-effort. A disconnected OBS instance should not automatically stop local DMX and visuals unless the cue explicitly requires OBS success.

### 5.5 Security

- credentials live in Keychain, not project JSON
- no credential values in execution logs
- allow loopback-only operation
- LAN operation requires explicit opt-in and clear host identity

## 6. Companion protocol

### 6.1 Transport

The first companion implementation can use the existing authenticated HTTP/WebSocket server, extended with v2 show endpoints. Apple platform peer-to-peer frameworks may be evaluated later, but the semantic protocol remains transport-independent.

### 6.2 Pairing

Recommended pairing flow:

1. Mac displays host name, fingerprint, and short-lived pairing code.
2. Phone discovers or manually enters host.
3. Phone confirms fingerprint/code.
4. Mac issues a revocable client credential stored in Keychain.
5. Each command includes client ID, monotonically increasing sequence, and command ID.

### 6.3 State synchronization

Companion state contains summaries, not complete project documents:

- show/run/revision IDs
- state version
- mode and held/parked state
- current setlist entry/song/section
- active and next cue
- preset summaries
- endpoint health
- execution warning summary

On reconnect, the client discards speculative state and accepts the authoritative host snapshot.

### 6.4 Command acknowledgement

Every command returns:

```json
{
  "commandID": "UUID",
  "accepted": true,
  "stateVersion": 43,
  "activeCueID": "UUID",
  "nextCueID": "UUID",
  "warnings": []
}
```

Duplicate command IDs return the original acknowledgement without re-executing effects.

## 7. iPhone app

Required first release surfaces:

- pairing/connection
- current and next cue
- GO / previous / next
- hold / resume / undo / park
- setlist list and jump
- preset/palette browser
- endpoint health
- confirmation sheets for blackout, haze, strobe, streaming, and destructive edits

Editing detailed cue payloads remains on Mac initially.

## 8. Apple Watch app

Watch receives a compact state through the iPhone or an explicitly designed direct path.

Pages:

1. **Cue:** current, next, GO, previous, next
2. **Control:** hold, resume, undo, park
3. **Looks:** a small curated preset list
4. **Safety:** blackout/kill actions requiring press-and-hold

Use haptics for accepted, rejected, and disconnected states. Never show success before host acknowledgement.

## 9. MIDI and hardware controllers

The S2 MK1 can become a dedicated Show Director controller without altering the S5/F1 default roles.

Suggested semantic mapping layers:

- Layer 1: show transport — GO, previous, next, hold, undo, park
- Layer 2: visual and palette presets
- Layer 3: lighting presets/intensity/movement
- Layer 4: video/overlay/OBS

Jog wheels can control normalized macros such as intensity, transition progress, movement speed, or visual energy. Mappings target `ShowControlCommand` and preset IDs, never raw implementation methods.

## 10. OSC routes

Preserve current `/cosmic/*` routes. Add versioned show routes:

```text
/cosmic/show/go
/cosmic/show/previous
/cosmic/show/next
/cosmic/show/hold
/cosmic/show/resume
/cosmic/show/undo
/cosmic/show/park
/cosmic/show/cue/jump <uuid>
/cosmic/show/section/jump <uuid>
/cosmic/show/preset/fire <uuid>
/cosmic/show/preset/insert_next <uuid>
/cosmic/show/preset/replace_next <uuid>
/cosmic/show/state/get
```

OSC UDP delivery is not inherently reliable. High-risk actions should be disabled over OSC by default or require an explicit safety setting and token.

## 11. Web API

Keep legacy endpoints. New routes:

```text
GET  /api/v2/show/state
POST /api/v2/show/command
GET  /api/v2/show/setlist
GET  /api/v2/show/presets
GET  /api/v2/show/execution-log?after=<sequence>
```

Large authoring documents can receive separate authenticated CRUD endpoints after the runtime path is stable.

## 12. External integration registry

Use a project-scoped registry for generic OSC/MIDI/HTTP endpoints:

```swift
struct ExternalEndpointDefinition: Codable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var kind: ExternalEndpointKind
    var configuration: ExternalEndpointConfiguration
    var safetyPolicy: ExternalEndpointSafetyPolicy
}
```

Secrets are referenced by Keychain key, never stored in the project package.

## 13. Integration validation checklist

Before marking an adapter shipped:

- [ ] capabilities are detected or declared
- [ ] connect/disconnect/reconnect tested
- [ ] timeout behavior tested
- [ ] duplicate command behavior tested
- [ ] secrets excluded from logs/packages
- [ ] endpoint failure policy tested
- [ ] manual fallback documented
- [ ] operator-facing status is accurate
- [ ] hardware/vendor version used for validation is recorded
