# Navigation IA spike (TabView vs sidebar)

**Date:** 2026-04-17  
**Status:** Decision recorded; no app code change required for this spike.

## Audit finding

[`fs-cos-vis-audit-and-docs-update/docs/FULL_PROJECT_AUDIT.md`](fs-cos-vis-audit-and-docs-update/docs/FULL_PROJECT_AUDIT.md): top-level **TabView** is clear but crowded as features grow; a **sidebar** navigation model may scale better long term.

## Current decision

- Keep **TabView** for **beta 0.1a** — lower risk, matches shipped app.  
- Revisit when **Lighting** or **Settings** growth forces clearer hierarchy or when user research demands it.

## Criteria to reconsider sidebar

- Operators frequently lose place between **Live Show** and **Lighting** during show prep.  
- Tab count or label truncation harms discoverability on smaller windows.  
- A sidebar would allow **nested** entries (e.g. Lighting → Patch / Cues / Stage) without more tabs.

## References

- [`03-ui-ux-spec.md`](03-ui-ux-spec.md) — IA section  
- [`todo-full-implementation.md`](todo-full-implementation.md) Section B  
