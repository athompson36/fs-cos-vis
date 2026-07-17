# FS COS VIS

FS COS VIS is a native macOS performance-visualization and DMX control app. The current direction is to evolve it into a Unified Show Director: one host application that coordinates visuals, lighting, overlays, video playback, recording, and remote cue control from shared song and section metadata.

## Current Product Shape

The app should be treated as a mature SwiftUI/Metal beta rather than a greenfield DMX controller. Existing work covers cosmic visual rendering, audio analysis, MIDI/OSC/web control, DMX patching, fixture planning, Art-Net/sACN/OpenDMX output, external display output, Syphon, recording, project folders, and packaged show assets.

The main missing layer is a typed, endpoint-neutral show timeline. Lighting cues, visual scenes, video clips, OBS overlays, recording markers, and remote commands need to be represented as one coherent performance score.

## Unified Show Director

The Show Director layer should support three cue sources:

- DJ mode: Traktor track, beatgrid, section, Remix Deck, and Maschine performance events.
- FOH setlist mode: manually advanced song and section cues for live bands.
- Manual mode: direct scene, palette, blackout, park, overlay, and video presets.

All cue sources feed the same endpoint model. A cue should not care whether it was triggered by Traktor, a setlist GO button, Apple Watch, MIDI, OSC, or the laptop UI.

## First Implementation Target

Build the host runtime before advanced automation:

1. Add Codable models for shows, setlists, songs, sections, cues, endpoint actions, presets, runtime overrides, and execution logs.
2. Add a deterministic reducer that transforms timeline state without endpoint I/O.
3. Add an actor-isolated execution engine that serializes cue execution and logs results.
4. Add adapters that call existing app services for visuals, palettes, lighting cues, backdrop video, overlays, recording, and utility actions.
5. Add a Guided Setlist workspace with current cue, next cue, GO, previous, next, hold, resume, repeat, jump, undo, park, and blackout.
6. Add protocol v2 commands for web, iPhone, Apple Watch, MIDI, and OSC remotes.

## Documentation

Start with:

- `docs/01-cursor-context.md`
- `docs/project-audit-and-feature-status.md`
- `docs/show-director-product-spec.md`
- `docs/show-director-architecture.md`
- `docs/show-director-implementation-roadmap.md`
- `docs/show-director-integrations.md`
- `docs/show-control-json-examples.md`
