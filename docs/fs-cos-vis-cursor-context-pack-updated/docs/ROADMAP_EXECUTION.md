# ROADMAP EXECUTION (Updated Repo Scan)

## Current truth

FS-COS-VIS is already a substantial implementation.
The job now is to finish it cleanly.

## Use this execution loop

### 1. Inspect
Open:
- relevant Swift/Metal files
- related tests
- related docs/spec files

### 2. Classify the task
Choose one:
- spec mismatch
- missing feature
- duplicated workflow
- reliability gap
- test gap
- docs drift

### 3. Choose the safest path
Prefer:
- patching an existing flow
- extending an existing flow
- consolidating overlapping UX

Avoid creating new parallel systems unless clearly necessary.

### 4. Complete the full vertical slice
A task is not done until:
- behavior exists
- UI is coherent
- persistence/state is correct if applicable
- docs are aligned
- tests are updated where practical

## Suggested current execution order

### Pass 1 — Spec alignment
- audit palette browser
- audit overlay manager
- audit quick palette access in live workflow

### Pass 2 — Show-critical hardening
- verification determinism
- stage plot polish
- recorder diagnostics / operator feedback

### Pass 3 — Control and transport parity
- OSC
- inbound DMX
- network multi-universe DMX

### Pass 4 — Release hardening
- package import/export automation
- smoke validation
- runbooks / docs / release prep