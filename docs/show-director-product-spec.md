# FS DMX Vision — Unified Show Director Product Specification

**Status:** Approved implementation context  
**Audience:** Cursor, maintainers, designers, QA, show operators  
**Scope:** Extend the existing macOS beta into a unified DJ, live-band, lighting, visual, overlay, recording, and remote show-control platform.

## 1. Product direction

FS DMX Vision is already a mature macOS visual instrument and lighting controller. The next product stage is **Unified Show Director**: one timeline and cue engine that coordinates every show endpoint regardless of how the cue is triggered.

The project must support two primary operating modes without creating separate products:

1. **DJ / electronic performance mode**
   - Traktor or another performance host provides track, transport, tempo, beat, and optional section events.
   - Maschine provides live instruments, groups, patterns, and performance events.
   - Track metadata and section metadata drive automatic or assisted scene changes.

2. **FOH / live-band setlist mode**
   - A prebuilt setlist contains songs and song sections.
   - The operator advances cues manually, semi-automatically, or from timecode/audio assistance.
   - macOS, iPhone, Apple Watch, MIDI controllers, OSC, and web clients can all issue the same semantic commands.

Both modes must target the same show endpoints:

- DMX lighting
- visual scenes and palettes
- backdrop video clips and generative visualizations
- overlay cards and text metadata
- OBS scenes, sources, filters, recording, and markers
- external display and Syphon output
- utility actions such as haze, blackout, park, hold, and restore
- future camera/PTZ, audio-console, and automation endpoints

## 2. Core product principle

**Cue sources and cue destinations must remain decoupled.**

A show cue must not care whether it was fired by:

- Traktor track or section metadata
- MIDI clock or Ableton Link-derived transport
- an iPhone GO button
- Apple Watch
- the macOS Setlist page
- the S2/F1 or another MIDI controller
- OSC / HTTP / WebSocket
- a timed event
- audio-assisted section detection

All cue sources call one execution API. All destination integrations are adapters behind that API.

## 3. Unified operating modes

### 3.1 Manual

The operator explicitly fires every cue. No automatic advancement.

### 3.2 Guided

The engine selects and displays the likely next cue but waits for **GO**. This is the default for FOH band operation.

### 3.3 Timed

Cues advance from authored offsets. The operator can hold, jump, skip, repeat, or resume at any point.

### 3.4 Track-aware

A detected/declared track identity loads its song score and follows beat/section metadata. The operator can override any event.

### 3.5 Fully automatic

Only for deterministic sources such as timecode, sequenced playback, or reliable host events. This must never be the default for an unpredictable live band.

## 4. Setlist workspace

Add a first-class **Setlist** surface to the macOS app. It is not a replacement for Live Show or Lighting; it is the show timeline and operator cue stack.

Required areas:

- show title, venue, performance date, mode, and connection health
- ordered setlist with songs, utility entries, intermission, walk-on, encore, and announcements
- expandable song sections
- active cue, elapsed time, and next cue preview
- GO, previous, next, hold, resume, undo, park, and jump
- manual scene/palette preset browser
- endpoint status summary
- cue execution log
- rehearsal timing capture

Example hierarchy:

```text
Show
└── Setlist
    ├── Walk-on
    ├── Song
    │   ├── Standby
    │   ├── Intro
    │   ├── Verse
    │   ├── Chorus
    │   ├── Solo
    │   ├── Breakdown
    │   ├── Finale
    │   └── Outro
    ├── Band introduction
    └── Encore
```

## 5. Manual preset workflow

Scene and palette libraries must support three live actions:

- **Fire now** — temporarily apply without changing the authored timeline.
- **Insert next** — add a runtime cue immediately after the current cue.
- **Replace upcoming** — substitute the next cue for this run while preserving the authored show file.

Manual overrides must be non-destructive until explicitly saved.

Preset types:

- lighting look
- palette
- movement/effect preset
- visual scene
- backdrop video
- overlay package
- OBS package
- complete show look containing several endpoints

Palettes must remain independent from movement and fixture intensity so operators can recombine a look and palette safely.

## 6. DJ and original-performance workflow

The target progression is:

1. Mix commercial tracks in Traktor.
2. Capture and perform Remix Deck loops.
3. Add Maschine instruments and patterns.
4. Associate songs with authored visual and lighting scores.
5. Perform original songs using track, stem, loop, and live-instrument events.

The app should accept track events through adapters rather than embedding Traktor-specific logic throughout the core.

Minimum normalized track event model:

- source application
- deck/player identifier
- track stable ID when available
- artist/title/file URL fingerprint
- BPM
- musical key when available
- transport state
- beat position and phase
- bar/phrase position when available or inferred
- active/master/on-air state
- section identifier
- confidence and timestamp

When exact Traktor metadata is unavailable, support progressively weaker sources:

1. explicit companion/plugin event feed
2. MIDI/OSC mapping and clock
3. local library/file matching
4. audio fingerprint and BPM inference
5. operator selection

The UI and documentation must label confidence honestly.

## 7. FOH band workflow

Before rehearsal:

1. Create/import show and venue.
2. Build or import the setlist.
3. Create song sections.
4. Assign cue packages and reusable presets.
5. Rehearse in Guided mode.
6. capture actual section durations.
7. refine cues and lock a show revision.

During the show:

1. Open the locked revision.
2. verify DMX, display, OBS, remote, and audio status.
3. run Guided mode.
4. advance from Mac, iPhone, Watch, MIDI, or OSC.
5. use Hold/Repeat/Jump/Park when the band deviates.
6. save an execution log as a new run, never overwrite the authored revision silently.

## 8. Companion applications

### 8.1 iPhone

The iPhone is a full remote client:

- current song and section
- next cue preview
- GO / previous / next
- hold / resume / undo / park
- setlist reorder, skip, insert, and encore controls
- preset and palette browser
- connection and endpoint health
- destructive-action confirmation
- offline cache of the active show and preset summaries

### 8.2 Apple Watch

The Watch is a deliberate, minimal control surface:

- GO
- previous / next
- hold / resume
- current and next cue
- small quick-look palette and energy presets
- safety actions behind press-and-hold

Do not place detailed editing on Watch.

### 8.3 Host authority

The macOS app is authoritative. Companion apps cache enough data to remain readable during brief disconnections, but they do not independently execute DMX or visual output.

## 9. Safety and reliability

Required live-show behaviors:

- idempotent cue execution
- monotonic sequence numbers for remote commands
- acknowledgements containing command ID and resulting state version
- reconnect and state resync
- undo based on complete prior show state
- park/safe-look state
- separate lighting blackout and video blackout
- kill strobe and stop movement
- haze emergency kill remains final override
- no cloud dependency during a show
- execution log with source, timestamp, result, and warnings
- authored state and runtime overrides remain distinct

## 10. Out of scope for the first implementation

- writing a custom macOS virtual audio driver
- replacing OBS compositing
- replacing Traktor or Maschine
- real-time AI autonomy without operator controls
- cloud-required execution
- pretending audio inference is equivalent to deterministic transport metadata

## 11. Product success criteria

The phase is successful when:

- one show cue can execute lighting, visual, overlay, backdrop, and OBS actions together
- the same cue can be fired from macOS, HTTP, OSC, MIDI, iPhone, and Watch
- a setlist can be rehearsed and run without editing raw JSON
- track-aware mode and setlist mode share the same runtime
- a disconnected remote cannot corrupt or fork live state
- the existing visual, lighting, project-package, and control-plane features continue to work
