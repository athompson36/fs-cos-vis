# Cursor Rules — FS-COS-VIS (Updated)

## 1. Audit before build
Before implementing any feature:
- inspect the current code paths
- inspect the relevant docs/spec
- determine whether the feature already exists partially
- determine whether the real need is completion, consolidation, or documentation alignment

## 2. No duplicate systems
This repo is now large enough that duplicate systems are a serious risk.
Do not create:
- second palette systems
- second overlay management flows
- second cue systems
- second mapping systems
- second save/export flows

Refine and consolidate first.

## 3. Spec mismatch rule
If docs and implementation disagree, Cursor must explicitly choose one:
- implement the missing spec
- revise the spec
- document the consolidation

Never leave the mismatch implicit.

## 4. Completion over novelty
Prefer:
- reliability
- UX clarity
- parity
- tests
- docs alignment

over:
- shiny stretch features
- speculative rewrites
- clever architecture work with no user benefit

## 5. Live usability protection
Any change must preserve or improve:
- dark-stage readability
- operator speed
- low-click access to important actions
- predictable state transitions
- performance safety

## 6. Drew Spaceman guardrail
Preserve the aesthetic:
- cosmic
- psychedelic
- glowy
- premium
- cinematic

But never let style reduce clarity in a live environment.

## 7. Testing rule
For logic-heavy or state-heavy changes, add tests when practical.
Prioritize tests for:
- BPM/tempo logic
- scene state
- serialization/migrations
- DMX routing/building
- mapping systems
- verification workflows
- stage plot model/state behavior

## 8. Documentation rule
Whenever a meaningful feature or workflow changes, update at least one of:
- README.md
- docs/03-ui-ux-spec.md
- docs/project-audit-and-feature-status.md
- docs/todo-full-implementation.md

## 9. Current priority order
1. spec mismatches
2. operator-critical UX gaps
3. verification/stability hardening
4. control parity
5. transport expansion
6. release packaging and docs

## 10. Required task loop
For each substantial task:
- Inspect
- Compare
- Plan
- Implement
- Validate
- Document

## Immediate audit targets
Start here unless the user directs otherwise:
- palette browser status
- overlay manager status
- quick palette strip/live palette access
- OSC parity
- inbound DMX
- stage plot polish
- verification determinism