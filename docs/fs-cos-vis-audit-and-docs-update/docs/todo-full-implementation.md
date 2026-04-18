# TODO - Full Implementation Backlog
Updated: 2026-04-17

## Current truth

Large portions of FS-COS-VIS are already implemented.
This backlog tracks what remains to make the product coherent, reliable, and release-ready.

## Priority P0 — Documentation coherence
- [ ] Rewrite README title/positioning from “Cursor Starter” to current beta app reality
- [ ] Refresh `docs/project-audit-and-feature-status.md`
- [ ] Refresh `docs/03-ui-ux-spec.md` to reflect current IA
- [ ] Reconcile `docs/todo-full-implementation.md` with current roadmap
- [ ] Document intentional consolidation of Palette Browser and Overlay Manager into Scene Studio

## Priority P1 — Live Show UX
- [ ] Add explicit audio input meter to Live Show
- [ ] Add stronger visual beat pulse indicator
- [ ] Reorganize live control bands:
  - performance actions
  - look/palette actions
  - capture/output actions
- [ ] Move authoring-heavy overlay utilities out of the main live action row
- [ ] Add clearer “current scene / palette / cue” summary strip

## Priority P2 — Scene Studio UX
- [ ] Improve sectional navigation for dense authoring controls
- [ ] Preserve consolidation, but strengthen sub-mode clarity:
  - Scene
  - Look
  - Liquid
  - Overlay
  - Palette
- [ ] Persist and refine expansion/collapse behavior for dense editing sections

## Priority P3 — Controller UX
- [ ] Improve mapping visibility and summary
- [ ] Add filter/search for larger fader sets
- [ ] Improve planned/disabled control labeling
- [ ] Verify MIDI / OSC / web command parity against native workflows

## Priority P4 — Lighting workspace UX
- [ ] Break Lighting Workspace into clearer sub-navigation
- [ ] Move JSON transport/import/export tools into an advanced/tools area
- [ ] Improve verification resume/correction workflows
- [ ] Continue stage plot polish and scanning ergonomics

## Priority P5 — Verification and testing
- [ ] Add deterministic tests for dual-camera fixture verification
- [ ] Add regression tests for stage layout camera overlays
- [ ] Harden cancellation/resume around camera disconnect/reconnect
- [ ] Improve confidence severity output and correction UX

## Priority P6 — Transport completion
- [ ] Complete Art-Net multi-universe flow
- [ ] Complete sACN multi-universe flow
- [ ] Complete inbound DMX merge path
- [ ] Advance RDM discovery/probing beyond scaffold status
- [ ] Expand performance profiling under larger loads

## Priority P7 — Release and installer readiness
- [ ] Prove signed/notarized beta pipeline end-to-end
- [ ] Harden Sparkle publication workflow
- [ ] Validate tester-ready DMG install flow on a non-Xcode Mac
- [ ] Validate ZIP + appcast path for updater distribution

## Done criteria
Treat full implementation as complete when:
1. docs/spec/roadmap all agree
2. live/performance UX is clearly separated from authoring
3. verification workflows are deterministic and test-covered
4. transport parity is honest and stable
5. beta tester can install and run without Xcode friction