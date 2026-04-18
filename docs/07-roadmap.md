# Roadmap

## Status snapshot (2026-04-17)

High-level status. Keep aligned with [`project-audit-and-feature-status.md`](project-audit-and-feature-status.md), [`todo-full-implementation.md`](todo-full-implementation.md), and [`03-ui-ux-spec.md`](03-ui-ux-spec.md). Installer choices: [`macOS-installer-options.md`](macOS-installer-options.md).

## Completed foundation

- Audio input picker, live analysis metrics, FFT/BPM feeds  
- Fractal + liquid render stack with compositing and palette controls  
  - Extended fractal zoom motion modes (Standard / Infinite Tunnel / Event Horizon) with higher modulation range  
- Live and studio control surfaces with external display routing  
  - Live output recorder with source picker, project-folder recording destination, and share/reveal flow  
  - First-run setup wizard with skippable steps (project/audio/output/DMX/AI)  
  - Beta update and operator feedback/reporting controls in Settings  
- Scene persistence, overlays, transitions, and performance workflow refinements  
- MIDI mapping baseline and remote/web control API foundation  
- **Show package** `.cosmicshow.zip` import/export in Settings; CI smoke workflow for package roundtrip (`show-package-smoke`)  
- DMX/lighting vertical slice:  
  - fixture library and patching  
  - cues and crossfades  
  - cue bookmark metadata for dynamic song/artist overlay values  
  - modulation runtime  
  - stage layout + 2.5D preview  
  - fog/haze learn and safety controls  
  - OFL import and enriched catalog (OFL sync + bundled curated fallback)  
  - fixture verification (assisted camera workflow); deterministic tests for dual-camera and stage-camera overlays; scan setup wizard and report UX improvements  
  - overlay element timeout auto-hide and metadata-bound text rendering  

## In progress

- Fixture verification **quality** pass: stronger confidence scoring, richer guidance, CV depth beyond luma heuristics where needed  
- Stage plot UX: ongoing polish (camera guidance, editing, scan/correction loops)  
- **Authoring consolidation (documented):** Palette Browser and Overlay Manager are **not** separate app screens — they live in **Scene Studio**; Live Show includes quick palette access  
- Network DMX: Art-Net/sACN **multi-universe** completion, inbound merge **production** readiness, RDM **beyond mock**  
- OSC / web / MIDI **parity matrix** vs native (systematic audit)  
- Capture/recording hardening, Sparkle publication, **signed/notarized** pipeline proof on real artifacts  
- Optional: navigation model spike (sidebar vs TabView) — see [`03-ui-ux-spec.md`](03-ui-ux-spec.md)  

## Next up (backlog)

- Art-Net/sACN: started — UDP send, settings, tests; finish multi-universe and operator docs  
- Inbound DMX + RDM: scaffolds in app; complete merge path and real RDM when ready  
- Performance profiling under **large** rigs (extend beyond current Settings diagnostics)  
- Live Show **UX**: input meter, beat pulse, action-band grouping, summary strip ([`todo-full-implementation.md`](todo-full-implementation.md) Section C)  
- Scene Studio **sectional** navigation; Settings **Basic/Advanced** for transports  
- Cross-platform feasibility (Windows) — spike only  

## Notes

- DMX stack remains USB/OpenDMX + simulation first while network transports mature; **label scaffolds honestly** in UI and docs.  
- Full “console parity” workflows wait on stable multi-universe/network transport.  
