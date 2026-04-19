# Historical audit pack vs live docs (Gate 0.1)

**Historical snapshot:** [`fs-cos-vis-audit-and-docs-update/`](fs-cos-vis-audit-and-docs-update/README_REPLACEMENT.md) — narrative audit and older copies of roadmap/todo.

**Live source of truth:** Root [`docs/`](../README.md#documentation-source-of-truth-order) per [`todo-full-implementation.md`](todo-full-implementation.md) audit reference.

## Reconciliation rules

1. **Prefer root `docs/`** for requirements, status, and backlog.  
2. **Historical pack:** Use for background context only; if a bullet conflicts with root `docs/`, **root wins**.  
3. **Duplicate filenames** under `fs-cos-vis-audit-and-docs-update/docs/` (e.g. old `07-roadmap.md`) are **superseded** by [`docs/07-roadmap.md`](07-roadmap.md).  
4. **`fs-cos-vis-cursor-context-pack-updated/`** is a Cursor context snapshot — not a second product spec.

## Contradictions to avoid

| Topic | Historical risk | Live position |
|-------|-----------------|----------------|
| IA: palette/overlay | May list standalone “browser” screens | **Scene Studio only** — [`03-ui-ux-spec.md`](03-ui-ux-spec.md), [`project-audit-and-feature-status.md`](project-audit-and-feature-status.md) |
| Beta scope | Mixed “starter” framing | **Late-stage beta** — [`README.md`](../README.md) |
| DMX claims | Outdated “scaffold only” | **Honest boundaries** — [`lighting-roadmap.md`](lighting-roadmap.md), Section I in [`todo-full-implementation.md`](todo-full-implementation.md) |

## Exit (Gate 0.1)

- [x] Reconciliation rules recorded (this file).  
- [ ] Any **new** contradiction found during the pass: fix root `docs/` or add one-line “supersedes” note in historical README only.

**Last updated:** 2026-04-19
