# Show Director Integrations

## Traktor

Use Traktor as a DJ event source, not as a hard dependency for the app.

Desired events:

- Track loaded.
- Active deck.
- BPM.
- Beat/bar/phrase position when available.
- Hot cue or section metadata.
- Loop state.
- Remix Deck cell activity.

Implementation notes:

- Prefer MIDI, OSC, controller mapping, and documented export metadata.
- Avoid relying on private Traktor internals.
- Treat Traktor events as normalized `PerformanceEvent` values.
- Manual override must always remain available.

## Maschine

Use Maschine as a live performance source.

Desired events:

- Project loaded.
- Scene selected.
- Group activity.
- Pad triggers.
- Macro changes.
- Transport/BPM via Ableton Link or MIDI clock.

Map events to lighting, video, overlay, or modulation cues where useful. Do not require Maschine for FOH mode.

## OBS

OBS should be controlled through OBS WebSocket where available.

Actions:

- Switch scene.
- Toggle source.
- Set text/source properties when supported.
- Start/stop recording.
- Add marker.
- Start/stop virtual camera or streaming if configured.

OBS failures should be logged and surfaced without stopping lighting or visual execution.

## DMX and Lighting

Use existing DMX services for OpenDMX, Art-Net, and sACN. The Show Director should invoke named lighting scenes, cues, palettes, or fixture-group actions through adapters.

Safety requirements:

- Kill strobe.
- Blackout.
- Park.
- Restore safe look.
- Respect fixture movement and intensity limits.

## QLC+

QLC+ can be used as an external lighting engine if helpful. The app should send OSC, MIDI, Art-Net, sACN, or other documented commands rather than assuming direct file control.

Use cases:

- Recall QLC+ scenes.
- Trigger chases.
- Control master intensity.
- Maintain compatibility with existing QLC+ show files.

## Video and Visuals

The app should support:

- Generated visual scenes.
- Backdrop video clips.
- Looping ambient clips.
- Section-specific transitions.
- Video blackout.
- Confidence monitor state.
- Clean projector output.

Video assets should be package-aware and validated for missing files.

## Overlays

Overlay packages should include:

- Band or artist title.
- Song title.
- Lower thirds.
- Lyrics.
- Logos.
- Sponsor or event cards.
- Hide all.

Overlays may be rendered internally or via OBS, but the cue model should be endpoint-neutral.

## Remote Control

The host app exposes semantic commands:

- `GO_NEXT_CUE`
- `HOLD_TIMELINE`
- `RESUME_TIMELINE`
- `JUMP_TO_SECTION`
- `FIRE_PRESET_NOW`
- `INSERT_PRESET_NEXT`
- `REPLACE_UPCOMING_CUE`
- `PARK`
- `BLACKOUT_LIGHTING`
- `BLACKOUT_VIDEO`
- `RESTORE_SAFE_LOOK`

The Mac remains authoritative.

## Audio Routing

Do not claim the app provides its own virtual audio driver. On macOS, use Core Audio and installed devices.

The app can manage routing profiles:

- Detect devices.
- Validate installed virtual devices such as BlackHole or Loopback.
- Recall aggregate or multi-output device choices where feasible.
- Explain missing device requirements.
- Map musical sources to technical channels in the UI.

Example:

```text
Maschine -> BlackHole 1-2 -> Traktor Deck D Live Input
Traktor Master -> S5 Main Out
Traktor Record Out -> OBS or Studio One
```
