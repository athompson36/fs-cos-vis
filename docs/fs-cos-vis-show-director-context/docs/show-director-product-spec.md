# Unified Show Director Product Spec

## Goal

Create a show-control layer that coordinates visuals, DMX lighting, backdrop media, overlays, OBS/recording actions, and remote controls from shared song and section metadata.

## Modes

### DJ Mode

Traktor and related performance tools provide timing and identity:

- Track loaded.
- Deck active.
- Beat/bar/phrase position.
- Hot cue or section metadata.
- Remix Deck clip activity.
- Maschine scene or pad activity.

The app maps those events to cue packages.

### FOH Setlist Mode

A live operator advances a prebuilt setlist while working front of house. The same endpoint actions are used, but timing comes from manual GO, hold, jump, and override actions.

### Manual Mode

The operator selects presets directly:

- Fire now.
- Insert next.
- Replace upcoming cue.
- Park.
- Blackout.
- Restore safe look.

## Users

- DJ building song-aware lights and visuals.
- Electronic performer combining Traktor, Maschine, video, and lighting.
- FOH engineer running band lighting and video from a setlist.
- Stream operator controlling OBS scenes, overlays, and recording markers.

## Setlist Workspace

The Setlist page should show:

- Current show.
- Ordered setlist.
- Current song and section.
- Next cue and major endpoint actions.
- Elapsed time.
- Endpoint health.
- Active manual overrides.
- GO, previous, next, hold, resume, repeat, jump, undo, park, blackout.
- Searchable preset browser.

## Remote Controls

### iPhone

Full remote operation:

- Current song/section.
- Next cue.
- GO.
- Previous/next.
- Hold/resume.
- Jump to section.
- Insert or replace preset.
- Fire quick scenes.
- Emergency controls.
- Endpoint health.

### Apple Watch

Limited, eyes-off operation:

- GO.
- Previous/next.
- Hold/resume.
- Quick safe looks.
- Quick palettes.
- Lighting blackout.
- Video blackout.
- Stop movement.
- Kill strobe.
- Restore safe look.

Destructive commands require press-and-hold or confirmation.

## Cue Package Endpoints

Supported endpoint families:

- Lighting: scene, cue, fixture group, intensity, movement, strobe, blackout, park.
- Palette: named color palette and transition.
- Visuals: generated scene, parameters, layers, fade.
- Backdrop video: clip, loop, transition, opacity, blackout.
- Overlay: lower third, lyrics, logo, title card, hide all.
- OBS: scene switch, source visibility, recording start/stop, marker.
- Camera: preset recall, source switch where available.
- Recording: start, stop, marker, file/session naming.
- Utility: house look, intermission, applause, safe mode.
- MIDI/OSC: outbound integration commands.
- Audio routing: recall routing profile using installed Core Audio devices.

## Live Band Requirements

Band performances are unpredictable. The system must support:

- Hold current look indefinitely.
- Repeat previous section.
- Extend current section.
- Jump to any section.
- Skip song.
- Insert announcement.
- Insert encore.
- Park in neutral look.
- Undo previous cue.
- Continue after network reconnect.

## Reliability Requirements

- No cloud dependency during show.
- Mac app is authoritative host.
- Remotes cache enough state to recover gracefully.
- Every command returns accepted/rejected/executed/failed status.
- Endpoint health is visible.
- Emergency controls remain available.
- Safe look is available if endpoint execution fails.
