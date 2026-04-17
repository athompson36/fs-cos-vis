# Lighting roadmap (implementation notes)

This document captures scope boundaries for the DMX lighting stack. It complements the product roadmap; it is not a feature checklist.

## Phases (summary)

1. **Fixture model & USB universe** — Profiles, instances, patch document, `DMXUniverseBuilder`, legacy CH 1–5 migration toggle, Application Support JSON.
2. **Cues** — `LightingCueDocument`, active cue, linear crossfade between cues using target fade time.
3. **Modulation** — `ModulationRuntime` routes LFO, tempo pulse, and per-band audio to channel offsets; summed per channel then applied once.
4. **2D stage** — Normalized placements, optional backdrop import under Application Support `Stage/`.
5. **2.5D preview** — Stylized beams and floor pools from fixture color channels (not photometric / IES truth).
6. **Copilot** — `LightingCopilotService` with validated `LightingPatchOperation` and heuristic helpers; structured LLM output can replace heuristics later.

## Non-goals (v1)

- GrandMA2 / full console compatibility, incoming DMX, or multi-universe over Art-Net/sACN (USB OpenDMX remains one outbound universe).
- Full trigger / envelope graph UI (runtime supports audio bands; advanced routing can build on the same document types).

## Persistence paths (Application Support `CosmicVisualizer/`)

| File | Content |
|------|-----------|
| `dmx_patch.json` | Profiles + instances + legacy toggle |
| `lighting_cues.json` | Cues + active index |
| `modulation.json` | Modulator definitions |
| `stage_layout.json` | Placements + backdrop path |
| `Stage/*.png` (etc.) | Imported stage backdrop copies |
