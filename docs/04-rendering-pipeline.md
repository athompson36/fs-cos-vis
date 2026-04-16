# Rendering Pipeline

## Target pipeline

1. gather latest audio features
2. update scene timing and beat phase
3. render liquid-light base pass
4. render fractal pass
5. render overlay pass
6. composite all layers
7. apply post-processing
8. present to screen / external display

## Fractal pass ideas

Support eventually:
- Julia
- Mandelbrot
- Burning Ship
- orbit-trap-based fields
- tunnel/warp variants

Audio-reactive parameters may include:
- zoom
- iteration depth
- hue shift
- glow amount
- swirl/turbulence
- camera drift

## Liquid-light pass ideas

Support:
- blob fields
- diffusion-like movement
- lens warping
- slow convection motion
- chromatic separation
- analog projector softness

## Composite behavior

Allow blend modes such as:
- screen
- add
- overlay
- soft light
- multiply
- lighten

