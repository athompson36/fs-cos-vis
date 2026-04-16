# Cursor Context: Cosmic Visualizer

## Project summary

Cosmic Visualizer is a real-time macOS visualization instrument for live music, creative ambience, projection work, and immersive display output.

The app combines:
- audio-reactive fractals
- BPM-aware timing and animation
- 60s-style liquid light visuals
- image overlays
- palettes and themes
- scene switching with previous / next controls
- fullscreen performance output

This is not a generic visualization toy. It should feel like a premium visual performance instrument with a strong artistic identity.

## Product intent

The app should be usable in four modes:
1. Fractal-only mode
2. Liquid-light-only mode
3. Hybrid fractal + liquid mode
4. Overlay-driven logo / artwork mode

## High-level product requirements

- user can select an audio input device
- app analyzes live audio in real time
- app detects tempo / BPM where possible
- app supports previous / next visualization scene switching
- app supports imported overlay images with blending
- app supports themes and palette presets
- liquid-light engine can run standalone or integrated with fractals
- app supports fullscreen or external-display output

## Technical direction

Build native on macOS first.

The repository includes a **buildable Xcode project** ([CosmicVisualizer.xcodeproj](CosmicVisualizer.xcodeproj)), generated from [project.yml](project.yml) via XcodeGen. Unit tests live in `CosmicVisualizer/CosmicVisualizerTests/`.

**Rule #1 — testing discipline:** when testing or changing code under test, fix and verify all errors and warnings before moving to the next step (full scheme test or `xcodebuild test`; no new unresolved warnings).

Preferred stack:
- SwiftUI for UI
- Metal for rendering
- AVFoundation/Core Audio for device management and capture
- Accelerate for FFT and spectral analysis

Avoid overengineering the first pass. Get a working vertical slice early:
- one audio input pipeline
- one BPM detector
- one fractal shader
- one liquid-light shader
- one overlay layer
- one palette system
- one preset/scene model

## Core system modules

- AudioEngine
- BPMDetector
- AudioFeatureExtractor
- SceneManager
- ThemeManager
- OverlayManager
- FractalRenderer
- LiquidLightRenderer
- CompositeRenderer
- PerformanceOutputManager

## Performance priorities

- stable frame pacing
- low-latency audio response
- graceful fallback when GPU load is high
- clean fullscreen mode
- smooth transitions between scenes

## UI philosophy

The UI should be performance-friendly and finger-friendly.
Avoid clutter.
The performance view should prioritize:
- previous / next scene
- audio input selection
- BPM display
- palette/theme quick selection
- overlay enable/disable
- fullscreen

## Aesthetic requirement

The app must align with the Drew Spaceman aesthetic:
- cosmic
- psychedelic
- dreamy
- analog liquid-light energy
- deep-space glow
- performance-ready
- not sterile, not corporate, not flat

Read `docs/06-drew-spaceman-aesthetic.md` before generating UI or visual ideas.

## Implementation behavior for Cursor

When implementing:
- preserve modular boundaries
- keep data models explicit
- avoid giant all-in-one files
- prefer testable systems for audio analysis and preset state (see module tests alongside `CosmicVisualizerTests`)
- keep shader parameters centralized
- document assumptions inside code
- do not replace the aesthetic with generic sci-fi minimalism

