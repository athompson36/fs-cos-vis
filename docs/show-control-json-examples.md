# Unified Show Director — JSON Examples

These examples communicate intended persistence and remote-protocol shape. Swift Codable models are the source of truth once implemented. All documents require explicit versions and migration tests.

## 1. Setlist document

```json
{
  "version": 1,
  "entries": [
    {
      "id": "13D2D158-37C8-4D7F-AC58-8261C3D62577",
      "kind": "utility",
      "title": "Walk-on",
      "songScoreID": null,
      "notes": "House lights down; logo and intro bed"
    },
    {
      "id": "6F79AD2F-D0D7-4997-BE5D-07EF31A4E86B",
      "kind": "song",
      "title": "Aurora",
      "songScoreID": "73DF2B93-5654-47C4-B7AC-689919FBFF18",
      "notes": "Hold after solo if the band extends"
    }
  ]
}
```

## 2. Song score

```json
{
  "version": 1,
  "songs": [
    {
      "id": "73DF2B93-5654-47C4-B7AC-689919FBFF18",
      "identity": {
        "title": "Aurora",
        "artist": "Flyover States",
        "externalIDs": {
          "traktor": "optional-stable-id"
        },
        "fileBookmarkID": "optional-security-scoped-bookmark-reference",
        "durationSeconds": 287.4,
        "fingerprint": null
      },
      "tempo": {
        "bpm": 124,
        "timeSignatureNumerator": 4,
        "timeSignatureDenominator": 4,
        "source": "authored",
        "confidence": 1
      },
      "defaultPresetID": "A9AC21C5-C50A-4AED-AF8E-7A3652756A3D",
      "sections": [
        {
          "id": "BFC34A08-10B4-4826-AD3A-2457EF19FF2F",
          "name": "Intro",
          "kind": "intro",
          "start": {
            "domain": "barBeat",
            "bar": 1,
            "beat": 1,
            "seconds": 0,
            "source": "authored",
            "confidence": 1
          },
          "duration": {
            "bars": 8,
            "beats": 32,
            "seconds": null
          },
          "cueIDs": [
            "676F79B8-3DA1-445A-8C99-89B0E8CF2139"
          ]
        },
        {
          "id": "5C7A349B-8DF0-43D3-BFE8-AF6921A91DB2",
          "name": "Final chorus",
          "kind": "chorus",
          "start": {
            "domain": "seconds",
            "seconds": 226.1,
            "bar": null,
            "beat": null,
            "source": "rehearsalObservation",
            "confidence": 0.94
          },
          "duration": {
            "bars": 16,
            "beats": 64,
            "seconds": 30.97
          },
          "cueIDs": [
            "561C2E37-175C-44D7-839D-64FEF0708E1C"
          ]
        }
      ]
    }
  ]
}
```

## 3. Show cue document

```json
{
  "version": 1,
  "activeCueID": null,
  "cues": [
    {
      "id": "561C2E37-175C-44D7-839D-64FEF0708E1C",
      "name": "Aurora — Final Chorus",
      "songID": "73DF2B93-5654-47C4-B7AC-689919FBFF18",
      "sectionID": "5C7A349B-8DF0-43D3-BFE8-AF6921A91DB2",
      "trigger": {
        "kind": "sectionEnter",
        "offsetBeats": 0,
        "automationPolicy": "guided"
      },
      "transition": {
        "durationSeconds": 0.5,
        "curve": "easeInOut"
      },
      "safetyClass": "normal",
      "tags": ["finale", "gold", "high-energy"],
      "notes": "May be fired manually if timing drifts",
      "actions": [
        {
          "type": "lighting",
          "policy": "required",
          "payload": {
            "operation": "activateCue",
            "lightingCueID": "BEF533A8-B041-4247-A640-249499E41845",
            "intensityScale": 0.88
          }
        },
        {
          "type": "palette",
          "policy": "required",
          "payload": {
            "paletteID": "5C0676B8-5E48-41BA-B672-82DAEB436A19",
            "scope": "visualAndLighting"
          }
        },
        {
          "type": "visual",
          "policy": "required",
          "payload": {
            "operation": "activateScene",
            "sceneID": "834E55E7-B768-4A2D-A35B-6DDA05163068"
          }
        },
        {
          "type": "backdrop",
          "policy": "bestEffort",
          "payload": {
            "operation": "playVideo",
            "assetPath": "Media/Video/aurora-final.mov",
            "loop": true,
            "transition": "flashDissolve"
          }
        },
        {
          "type": "overlay",
          "policy": "bestEffort",
          "payload": {
            "operation": "hideAllTransient"
          }
        },
        {
          "type": "obs",
          "policy": "bestEffort",
          "payload": {
            "operation": "setProgramScene",
            "sceneName": "Performance Wide"
          }
        },
        {
          "type": "recording",
          "policy": "bestEffort",
          "payload": {
            "operation": "addMarker",
            "label": "Aurora — Final Chorus"
          }
        }
      ]
    }
  ]
}
```

## 4. Preset library

```json
{
  "version": 1,
  "presets": [
    {
      "id": "A9AC21C5-C50A-4AED-AF8E-7A3652756A3D",
      "name": "Cosmic Violet — Ambient",
      "kind": "completeLook",
      "tags": ["cosmic", "purple", "ambient"],
      "safetyClass": "normal",
      "actions": [
        {
          "type": "lighting",
          "policy": "required",
          "payload": {
            "operation": "activateCue",
            "lightingCueID": "E3CA6CE4-A0DF-4410-8CDA-6066D3E25EEA",
            "intensityScale": 0.52
          }
        },
        {
          "type": "palette",
          "policy": "required",
          "payload": {
            "paletteID": "51C76A7D-A1AA-4B40-995D-457417CE6E44",
            "scope": "visualAndLighting"
          }
        },
        {
          "type": "visual",
          "policy": "required",
          "payload": {
            "operation": "activateScene",
            "sceneID": "3E594F5D-D625-499C-9AF6-C8E6DD9A0169"
          }
        }
      ]
    }
  ]
}
```

## 5. Runtime state

```json
{
  "protocolVersion": 2,
  "showID": "6CF64417-3E17-4B0F-B151-4598FC3E4CD7",
  "revisionID": "2668B378-C758-444C-9FD5-A8099A5984DB",
  "runID": "62368B15-6F69-4A30-BEB8-C6F92ECF6BCA",
  "stateVersion": 42,
  "mode": "guided",
  "held": false,
  "parked": false,
  "currentEntryID": "6F79AD2F-D0D7-4997-BE5D-07EF31A4E86B",
  "currentSectionID": "5C7A349B-8DF0-43D3-BFE8-AF6921A91DB2",
  "activeCue": {
    "id": "561C2E37-175C-44D7-839D-64FEF0708E1C",
    "name": "Aurora — Final Chorus"
  },
  "nextCue": {
    "id": "93961077-958B-46B5-9477-CE2E8DBA53A3",
    "name": "Aurora — Outro"
  },
  "runtimeOverrideCount": 1,
  "endpointHealth": [
    {
      "id": "lighting.local",
      "status": "healthy",
      "message": "OpenDMX output active"
    },
    {
      "id": "obs.main",
      "status": "degraded",
      "message": "Disconnected; actions are best-effort"
    }
  ]
}
```

## 6. V2 command envelope

```json
{
  "protocolVersion": 2,
  "commandID": "34DC003A-8457-4C45-84AE-DF87D8F4A315",
  "clientID": "5133EDCA-EF28-4570-9E69-20C5044CF6BA",
  "sequence": 119,
  "sentAt": "2026-07-16T19:42:17Z",
  "expectedStateVersion": 42,
  "command": {
    "type": "go"
  }
}
```

Preset override command:

```json
{
  "protocolVersion": 2,
  "commandID": "634A77F1-469D-4D82-9526-5E1171AC5EB2",
  "clientID": "5133EDCA-EF28-4570-9E69-20C5044CF6BA",
  "sequence": 120,
  "sentAt": "2026-07-16T19:42:22Z",
  "expectedStateVersion": 43,
  "command": {
    "type": "insertPresetNext",
    "presetID": "A9AC21C5-C50A-4AED-AF8E-7A3652756A3D"
  }
}
```

## 7. V2 acknowledgement

```json
{
  "protocolVersion": 2,
  "commandID": "34DC003A-8457-4C45-84AE-DF87D8F4A315",
  "accepted": true,
  "duplicate": false,
  "stateVersion": 43,
  "activeCueID": "561C2E37-175C-44D7-839D-64FEF0708E1C",
  "nextCueID": "93961077-958B-46B5-9477-CE2E8DBA53A3",
  "warnings": [
    "OBS endpoint disconnected; best-effort action skipped"
  ],
  "endpointResults": [
    {
      "endpoint": "lighting.local",
      "status": "success",
      "durationMS": 4.8
    },
    {
      "endpoint": "obs.main",
      "status": "skipped",
      "durationMS": 0
    }
  ]
}
```

Conflict response:

```json
{
  "protocolVersion": 2,
  "commandID": "B771728C-1CC8-4490-88DA-780CA26E2810",
  "accepted": false,
  "duplicate": false,
  "stateVersion": 48,
  "error": {
    "code": "state_version_conflict",
    "message": "Client expected version 43; host is version 48. Refresh state before retrying."
  }
}
```

## 8. Normalized track event

```json
{
  "source": "traktorBridge",
  "sourceInstanceID": "macbook-performance",
  "deckID": "A",
  "eventType": "transportUpdate",
  "trackIdentity": {
    "externalID": "optional",
    "artist": "Artist",
    "title": "Track",
    "filePath": null,
    "durationSeconds": 312.4
  },
  "transport": {
    "playing": true,
    "master": true,
    "onAir": true,
    "bpm": 124,
    "beatPhase": 0.03,
    "beatIndex": 257,
    "bar": 65,
    "beatInBar": 1
  },
  "sectionID": null,
  "confidence": 0.82,
  "timestamp": "2026-07-16T19:42:17.281Z"
}
```

## 9. Execution log JSON Lines

Each line is independently appendable and decodable:

```json
{"sequence":1,"timestamp":"2026-07-16T19:00:00Z","kind":"runStarted","source":"macOS","stateVersion":1,"details":{"mode":"guided"}}
{"sequence":2,"timestamp":"2026-07-16T19:00:03Z","kind":"cueExecuted","source":"iPhone:5133EDCA-EF28-4570-9E69-20C5044CF6BA","commandID":"34DC003A-8457-4C45-84AE-DF87D8F4A315","cueID":"561C2E37-175C-44D7-839D-64FEF0708E1C","stateVersion":2,"result":"success","warnings":["OBS skipped"]}
{"sequence":3,"timestamp":"2026-07-16T19:00:18Z","kind":"holdChanged","source":"AppleWatch","stateVersion":3,"details":{"held":true}}
```

## 10. Migration expectations

- Missing new files in an older project mean empty/default documents.
- Unknown enum cases must fail with an actionable migration error or decode through an explicitly designed unknown case; never silently execute an unknown action.
- Referenced IDs that no longer exist produce validation findings.
- Absolute media paths should be migrated to project-relative paths where possible.
- Secrets are never represented in these documents.
