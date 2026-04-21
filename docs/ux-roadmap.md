# Usability roadmap (phased)

Cross-cutting UX goals derived from **operator-first** lighting/visual workflows (value source clarity, recallable layouts, consistent naming) mapped to this app without duplicating full console products. Align with [`03-ui-ux-spec.md`](03-ui-ux-spec.md) and [`lighting-control-strategies.md`](lighting-control-strategies.md).

**Phase A — Clarity under stress (Live Show / performance)**  
Strengthen at-a-glance understanding of **what drives lights**: cue vs modulation vs inbound merge—copy and subtle affordances on the active strip; keep Performance mode visually quiet per the [`live_show`](../.cursor/rules/live_show.mdc) rule.

**Phase B — Remote operator parity**  
HTTP `/api/state` + bundled web UI show transport and **inbound** status; document settings keys in [`control-parity.md`](control-parity.md). Optional: short “effective stack” blurb in `/api/schema` help text.

**Phase C — Power-user efficiency (Lighting / Controller)**  
Keyboard-friendly cue navigation where safe; persist filters; reduce dead-end “Planned” affordances by pointing to HTTP/MIDI equivalents in copy or links.

**Phase D — Desk-grade DMX**  
Inbound and output diagnostics visible in Settings Advanced tier; cross-link [`dmx-lab-procedures.md`](dmx-lab-procedures.md) for field validation.

**Deeper competitive UX** (MA3, Eos, Onyx-style task studies): optional future spike with screenshots and measured flows—not blocking phased work above.

Last updated: 2026-04-21
