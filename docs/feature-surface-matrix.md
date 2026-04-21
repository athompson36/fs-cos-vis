# Feature × control surface matrix (Gate 0.2)

**Purpose:** High-level coverage map for production pass. **Legend:** ● = primary path, ○ = partial / REST / advanced, — = not applicable, (T) = automated tests exist.

Rows follow [`project-audit-and-feature-status.md`](project-audit-and-feature-status.md). This is a **summary**; detailed command lists are in [`control-parity.md`](control-parity.md) and [`control-schema-coverage.md`](control-schema-coverage.md).

| Area | Native UI | `POST /api/command` | MIDI | OSC | `/api/state` + WS | Tests | Manual UAT |
|------|-----------|---------------------|------|-----|-------------------|-------|------------|
| Scene library / edit / transitions | ● | ● raw + REST scenes | ● discrete | ● | ● | (T) | Live Show + Studio |
| Fractal + liquid + composite | ● | ● | ● CC | ● | ● | (T) | Scene Studio |
| Palettes / themes | ● Studio | ○ `SetSelectedPalette` raw | ○ | ○ | ● | (T) | — |
| Overlays | ● Studio | ○ | ○ | ○ | ● | (T) | — |
| Live Show performance UX | ● | ● | ● | ● | ● | (T) | Gate 4 checklist |
| External display / fullscreen | ● | ● | ○ | ○ | ● | (T) | — |
| Audio input / BPM / beat | ● | ○ | ● | ● | ● | (T) | — |
| Live output recorder | ● | ● | ○ | ● | ● | (T) | — |
| Remote HTTP + WS | — | ● | — | — | ● | (T) | — |
| MIDI mapping | ● | REST midi map | ● | — | ● | (T) | Controller |
| OSC | Settings on | raw same as HTTP | — | ● | ○ state query | (T) ControlBus | `osc-control.md` |
| DMX patch / cues / stage | ● | ○ mostly Settings | ○ DMX faders | ○ | ○ | (T) | Lighting WS |
| DMX network Art-Net/sACN | ● Settings | ○ settings via PUT | — | — | ○ output diag | (T) partial | **Lab Gate 3a–b** |
| Inbound DMX merge (Art-Net/sACN + USB serial OpenDMX-class) | ● Settings | — | — | — | ● `GET/PUT /api/settings` + inbound fields / telemetry on `/api/state` | (T) | Lab / [`control-parity.md`](control-parity.md) |
| Show project / zip | ● | REST + archive | — | — | ○ | (T) show package | — |
| Updates / feedback / wizard | ● | — | — | — | ○ | partial | beta docs |

**IA note:** There is **no** standalone Palette Browser or Overlay Manager app screen — consolidated in **Scene Studio** (N/A column = not a separate surface).

**UI trace:** Primary screens vs code — [`ui-page-verification.md`](ui-page-verification.md).

**Last updated:** 2026-04-21 — inbound DMX row: Settings + REST settings + `/api/state` telemetry; fractal/liquid row includes **spectrum warp** + **geometry 0…6** on native + `POST /api/command` / OSC (`SetSpectrumWarpAmount`, `SetFractalGeometryIndex`).
