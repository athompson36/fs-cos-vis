# UI / UX spec

**Last updated:** 2026-04-19  

Describes **information architecture**, **primary screens**, interaction priorities, and **Drew Spaceman** style constraints. Further Live Show polish (if any) is tracked in [`todo-full-implementation.md`](todo-full-implementation.md) (Section C). IA and surface naming align with [`production-readiness-checklist.md`](production-readiness-checklist.md) (Gates 0 / 4) and [`uat-checklist.md`](uat-checklist.md).

## Information architecture

Top-level navigation today uses a **TabView**: Live Show, Scene Studio, Controller, Settings, Lighting Workspace. A future **sidebar** layout may scale better; that remains a design spike, not a committed change.

### Intentional consolidation (not missing features)

- **There is no separate “Theme / Palette Browser” app screen.** Palette library, palette wizard/color wheel, and palette selection for performance live in **Scene Studio** (and quick palette access in Live Show).
- **There is no separate “Overlay Manager” app screen.** Overlay card authoring and logo/placement work live in **Scene Studio**.

Document these as **consolidated surfaces**, not as missing routes.

## Primary screens

### 1. Live Show (performance view)

Primary **performance** screen. Must keep critical actions obvious and avoid blocking the Metal preview with heavy inspectors.

**Implemented:**

- Audio device selector; input channel selector (mono / stereo / mix)  
- **Input level meter** (RMS/peak bar); **beat-phase ring** (`tempoClock.beatPhase`) plus BPM and beat confidence in the Performance group  
- **Active summary strip** (scene name, palette name, active lighting cue name)  
- BPM readout; scene prev / next / random; fullscreen; tap tempo  
- **Grouped bands:** Performance (scene + tempo + overlay file tools menu), Look / palette, Capture / output (recorder)  
- Quick palette access; liquid toggle; overlay enable/placement toggle  
- Haze emergency kill; live output recorder (source, quality, share/reveal)  
- Performance toggle; cue strips (scene / lighting / backdrop as configured)  
- Overlay import / black-removal **file tools** in a **menu** (not primary buttons)  

**Optional polish** (see backlog if we add more):

- Further density tuning without crowding the Metal preview  

### 2. Scene Studio (scene editor + consolidated authoring)

Primary **creative** surface: scene list, live preview, fractal and liquid controls, overlay authoring, palette creation/selection, dropper layer editing.

**Authoring sub-modes** (implemented as a **persisted section picker** in the controls column):

- Scene · Look · Fractal · Liquid · Overlay · Palette  

Preview vs control column split is **intentional** (authoring density).

### 3. Controller

Mapping / performance control: tempo, MIDI learn, faders, DMX-oriented groups, status.

**Implemented:** Overview **mapping cards** (MIDI continuous, MIDI triggers, OSC examples); Faders tab **fixture search**; **Planned** badges on unavailable learn modes; **visual separation** of scene (layer/MIDI) vs fixture **DMX manual** faders with distinct captions and tinted group regions.

### 4. Settings

Configuration, updates, feedback, show package import/export, AI, remote HTTP/WebSocket, OSC, audio, DMX transports and diagnostics.

**Implemented:** **Basic / Advanced** tier (persisted) for **DMX & network transport** — Basic keeps endpoints and inbound merge controls readable; Advanced adds Art-Net/sACN **LAN/Wi‑Fi** and multicast hints, grouped **Diagnostics** (output stream, inbound receiver, frame timing), and full **RDM** controls.

### 5. Lighting Workspace

**Implemented:** Five tabs — **Patch** (OFL + DMX patch + rig list), **Cues** (lighting + backdrop cues), **Stage** (plan + 2.5D preview + exposure tip for camera probes), **Verify** (assisted fixture verification; amber **exposure/contrast** banner; **run + per-fixture confidence** from luma signal and category checks), **Tools** (modulation, bulk JSON import/export, copilot). Patch and cue lists support **search/filter** for larger shows.

## Interaction priorities

- Live actions must stay **obvious and low-risk**; authoring must not crowd performance.  
- Current state must read well in **low light** (contrast, grouping).  
- Network DMX features that remain **partial** (e.g. RDM beyond mock, sACN discovery) must stay **honestly labeled** in UI and docs.  
- Advanced tools accessible but not visually dominant.  

## Style notes (premium cosmic control panel)

- Translucent surfaces where layering helps; soft bloom/glow accents; rounded controls  
- Strong contrast in dark environments; clear grouping; avoid clutter  

## Drew Spaceman style rule (non-regression)

The UI should feel **cosmic, psychedelic, cinematic, rich, immersive**. It should **not** feel sterile, generic-enterprise, toy-like, or visually muddy. Future polish must preserve operator clarity under stage lighting.
