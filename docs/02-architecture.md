# Architecture

## Overview

Use a layered architecture.

### Layer 1: Audio input and analysis
Responsibilities:
- enumerate audio devices
- select input source
- capture audio buffers
- compute RMS / peak / FFT features
- estimate BPM
- detect transients / beats
- expose smoothed control values

### Layer 2: Scene state
Responsibilities:
- active scene selection
- previous/next scene navigation
- scene parameter storage
- theme/palette assignment
- overlay references
- audio mapping configuration

### Layer 3: Rendering passes
Responsibilities:
- fractal render pass
- liquid-light render pass
- overlay render pass
- compositing pass
- optional post FX pass

### Layer 4: UI / control surface
Responsibilities:
- device picker
- previous/next controls
- scene browser
- palette/theme controls
- overlay manager
- fullscreen/performance toggles

## Data models

Recommended models:
- `AudioFeatures`
- `BeatState`
- `BPMState`
- `VisualizationScene`
- `ThemePalette`
- `OverlayAsset`
- `RenderParameters`
- `TransitionState`

## Modular principle

The renderer consumes normalized control values.
It should not know where those values came from.
That keeps audio, MIDI, automation, and future network control extensible.

