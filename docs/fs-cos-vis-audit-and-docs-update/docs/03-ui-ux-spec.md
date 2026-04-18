# UI / UX Spec
Updated: 2026-04-17

## Information architecture

## Primary screens

### 1. Live Show
Primary performance-use screen.

Required live controls:
- audio device selector
- input channel selector
- audio input meter
- BPM readout
- beat indicator / pulse
- previous scene
- next scene
- random scene
- fullscreen
- quick palette access
- liquid light toggle
- overlay enable/placement toggle
- haze emergency kill
- live recorder controls

### 2. Scene Studio
Primary creative authoring surface.

This screen intentionally consolidates:
- scene editing
- palette management
- overlay authoring
- fractal editing
- liquid-light editing

Recommended sub-sections:
- Scene
- Look
- Fractal
- Liquid
- Overlay
- Palette

### 3. Controller
Mapping / performance-control surface.

Responsibilities:
- tempo source and BPM control
- MIDI learn
- control summaries
- performance faders
- DMX control groups
- mapping visibility

### 4. Settings
Configuration / packaging / transport / beta operations.

Responsibilities:
- updates
- feedback bundle / issue submission
- project package export/import
- AI provider config
- remote control and OSC
- audio routing
- DMX transport and diagnostics

### 5. Lighting Workspace
Lighting authoring / planning / verification surface.

Recommended internal grouping:
- Patch
- Cues
- Stage
- Verify
- Tools

## Interaction priorities

- live actions must remain obvious and low-risk
- setup/authoring actions should not crowd performance actions
- current state should be easy to read in low light
- transport scaffolds must be honestly labeled
- advanced tooling should be accessible but not visually dominant
- the app should feel premium, cosmic, and glowy without reducing operator clarity

## Style notes

Use a premium cosmic control-panel feel:
- translucent surfaces where they help layering
- bloom/glow accents
- rounded controls
- strong contrast in dark environments
- clear grouping
- avoid clutter

## Drew Spaceman style rule

The UI should feel:
- cosmic
- psychedelic
- cinematic
- rich
- immersive

It should not feel:
- sterile
- generic enterprise
- toy-like
- visually muddy