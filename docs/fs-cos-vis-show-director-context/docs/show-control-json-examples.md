# Show Control JSON Examples

These examples define the intended shape of the Show Director data model. They are not a final API contract until implemented and versioned in code.

## Show Document

```json
{
  "schemaVersion": 1,
  "id": "show_flyover_demo",
  "name": "Flyover Demo Show",
  "defaultSetlistId": "setlist_main",
  "setlists": [
    {
      "id": "setlist_main",
      "name": "Main Set",
      "items": [
        {
          "id": "item_001",
          "songScoreId": "song_aurora",
          "label": "Aurora"
        }
      ]
    }
  ]
}
```

## Song Score

```json
{
  "schemaVersion": 1,
  "id": "song_aurora",
  "artist": "Flyover States",
  "title": "Aurora",
  "bpm": 124,
  "key": "8A",
  "sections": [
    {
      "id": "section_intro",
      "name": "Intro",
      "type": "intro",
      "cuePackageId": "cue_aurora_intro"
    },
    {
      "id": "section_drop",
      "name": "Drop",
      "type": "drop",
      "cuePackageId": "cue_aurora_drop"
    }
  ]
}
```

## Cue Package

```json
{
  "schemaVersion": 1,
  "id": "cue_aurora_drop",
  "name": "Aurora Drop",
  "actions": [
    {
      "id": "action_light_drop",
      "endpoint": "lighting",
      "type": "recallScene",
      "sceneId": "lighting_gold_white_full",
      "fadeMs": 250
    },
    {
      "id": "action_palette_drop",
      "endpoint": "palette",
      "type": "applyPalette",
      "paletteId": "palette_cosmic_violet",
      "fadeMs": 500
    },
    {
      "id": "action_video_drop",
      "endpoint": "backdropVideo",
      "type": "playClip",
      "clipId": "video_aurora_drop",
      "transition": "flashDissolve",
      "loop": true
    },
    {
      "id": "action_obs_marker",
      "endpoint": "obs",
      "type": "addMarker",
      "label": "Aurora - Drop"
    }
  ]
}
```

## Remote Command

```json
{
  "protocolVersion": 2,
  "commandId": "cmd_2026_0001",
  "source": "appleWatch",
  "type": "GO_NEXT_CUE",
  "showId": "show_flyover_demo",
  "expectedRuntimeRevision": 42
}
```

## Manual Preset Override

```json
{
  "protocolVersion": 2,
  "commandId": "cmd_2026_0002",
  "source": "iphone",
  "type": "INSERT_PRESET_NEXT",
  "presetId": "preset_purple_psychedelic",
  "label": "Purple Psychedelic",
  "afterCurrentCue": true
}
```

## Execution Log Entry

```json
{
  "id": "log_000012",
  "timestamp": "2026-07-17T00:15:42Z",
  "commandId": "cmd_2026_0001",
  "cuePackageId": "cue_aurora_drop",
  "results": [
    {
      "actionId": "action_light_drop",
      "endpoint": "lighting",
      "status": "executed",
      "durationMs": 41
    },
    {
      "actionId": "action_video_drop",
      "endpoint": "backdropVideo",
      "status": "executed",
      "durationMs": 86
    },
    {
      "actionId": "action_obs_marker",
      "endpoint": "obs",
      "status": "failed",
      "message": "OBS WebSocket disconnected",
      "durationMs": 1000
    }
  ],
  "runtimeRevisionBefore": 42,
  "runtimeRevisionAfter": 43
}
```
