# FS-COS-VIS Cursor Project Context (Updated Repo Scan)

## Project identity

FS-COS-VIS is a **hybrid macOS performance platform** that combines:

1. a real-time cosmic visualizer
2. a scene-based fractal + liquid-light engine
3. a live lighting / patch / cue / verification workspace

Cursor must no longer treat this repository as an early starter.
It is a **late-stage hybrid visualizer + show-control application**.

## Practical product definition

This repo currently sits between two identities:
- a cosmic visual performance instrument
- a show-control and lighting workspace

The correct working definition is:

**Build it as a cosmic performance instrument with a real show-operations spine.**

That means Cursor must protect both:
- artistic/psychedelic visual identity
- operator clarity and reliability

## Repo-verified current implementation

Cursor should assume these are already substantially present:

- scene management and scene editing
- live show view
- scene studio
- controller view
- settings and lighting workspace
- fractal + liquid + composite rendering
- palette/theme systems
- audio device selection and BPM feeds
- external display routing
- web control server
- MIDI mapping
- lighting patch/cue/modulation systems
- stage plot / stage layout features
- OFL import
- fixture verification workflows

## Main current risk

The main problem is not lack of architecture.
The main problem is **completion discipline**:

- spec vs implementation drift
- duplicated workflows
- partial parity across control systems
- reliability gaps in show-critical flows
- backlog items that are easy to defer because the app already “looks advanced”

## Drew Spaceman aesthetic system

This remains a governing design system.

### Keywords
- cosmic
- psychedelic
- celestial
- analog liquid-light
- prism bloom
- glowy
- cinematic
- dark-stage legible
- immersive
- premium

### Do not drift into
- sterile enterprise UI
- flat generic utility UI
- over-minimal “Apple clone” control surfaces
- decorative clutter that hurts live usability

### Visual priority rule
When aesthetic and operator clarity conflict, operator clarity wins.

## Updated roadmap emphasis

### Highest-value current audits
Cursor should inspect these first:
- Palette Browser gap
- Overlay Manager gap
- quick palette access in Live Show
- OSC parity gap
- inbound DMX gap
- stage plot UX polish gaps
- verification determinism/testing gaps

### Highest-value current implementation order
1. close spec mismatches
2. harden verification and stage/operator flows
3. complete transport/control parity
4. finalize packaging and release-readiness

## Definition of done

100% complete means:

- all promised visualizer UX flows are real and coherent
- all promised show-control workflows are production-usable
- docs/spec match reality
- BPM/tempo behavior is musically useful
- control parity is intentional across supported protocols
- verification workflows are deterministic and test-covered
- long-run stability is acceptable for real use

## Required Cursor behavior

For every major task:
1. inspect current implementation first
2. inspect docs/spec before coding
3. identify whether the task is:
   - missing
   - duplicated
   - partial
   - already complete
4. prefer refining current systems over inventing parallel ones
5. update docs when behavior changes
6. add tests where logic/state changed

## Files Cursor should keep aligned

- README.md
- docs/03-ui-ux-spec.md
- docs/project-audit-and-feature-status.md
- docs/todo-full-implementation.md
- roadmap docs
- in-app labels and tab names

## Final operating mindset

Do not build random new subsystems.
Do not confuse “many implemented files” with “finished product.”
Push the project toward:
- coherence
- show-safety
- spec alignment
- strong Drew Spaceman identity
- disciplined completion