# Project Audit and Feature Status

## Audit Summary

The project should be considered a capable native macOS visual and lighting application with a substantial foundation already present. The next stage is not to build basic DMX control. The next stage is to unify existing capabilities under a typed show timeline and reliable execution engine.

## Existing Strengths

- Native macOS app direction is appropriate for low-latency visuals, Core Audio integration, display output, MIDI, OSC, and DMX workflows.
- SwiftUI is suitable for editor and control surfaces.
- Metal or GPU rendering is suitable for projector and display visuals.
- Existing audio analysis, BPM, beat phase, and MIDI clock concepts can drive beat-aware visuals and modulation.
- Existing DMX concepts such as patching, fixtures, cues, universes, OpenDMX, Art-Net, and sACN are directly reusable.
- Existing protocol surfaces can evolve into remote control for phone, watch, browser, MIDI, OSC, and show devices.
- Existing project packaging can become the container for show metadata, media references, and cue logs.

## Primary Gap

The app lacks a central endpoint-neutral performance timeline.

Without that layer, lighting, visuals, video, overlays, and recording remain separate features. With that layer, a song section can trigger a single cue package:

- Change lighting scene.
- Apply color palette.
- Start backdrop video.
- Switch overlay state.
- Change OBS scene.
- Add recording marker.
- Set safe movement/intensity limits.
- Notify remotes.

## Development Position

The project is ready for a Show Director milestone if the implementation stays incremental:

1. Model and reducer first.
2. Fake endpoints second.
3. Existing app adapters third.
4. UI fourth.
5. Remote protocol fifth.
6. Traktor/Maschine automation after the local runtime is stable.

## Risks

- Endpoint-specific models leaking into the show timeline.
- Cue execution happening directly in SwiftUI views.
- Remote clients being allowed to own runtime state.
- Long-running network or hardware calls blocking cue sequencing.
- Building Apple Watch and phone UI before the host protocol is stable.
- Overpromising automatic audio routing instead of managing installed Core Audio devices.
- Using undocumented Traktor or Maschine internals as hard dependencies.

## Recommended Engineering Posture

- Prefer typed enums over stringly typed endpoint actions.
- Use stable IDs for every show, song, section, cue, preset, and endpoint.
- Keep reducers pure and deterministic.
- Put hardware and network I/O behind adapters.
- Make the Mac app the authoritative host.
- Log every cue command, result, skip, failure, override, and emergency action.
- Store show metadata as versioned JSON inside the existing package format.

## Definition of First Success

A user can create a setlist, assign a few sections, attach lighting/visual/video/overlay actions, press GO through the set, hold or jump when the band changes direction, fire a manual preset, and later inspect what actually executed.
