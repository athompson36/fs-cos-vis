# Audio Reactivity and BPM

## Why BPM matters

The app should not only react to loudness. It should understand time.

BPM drives:
- animation rate
- pulse intervals
- zoom rhythm
- liquid-light expansion timing
- glow swells
- scene transition cadence
- auto-cycle behavior

## Audio feature set

Recommended features:
- RMS
- peak
- low/mid/high band energy
- spectral flux
- spectral centroid
- transient confidence
- beat confidence
- estimated BPM
- phase within beat/bar if possible

## Recommended control mappings

- bass -> zoom pulse / blob expansion
- mids -> swirl / turbulence / rotation
- highs -> shimmer / edge detail / spark
- beat pulse -> bloom surge / flash / accent reveal
- BPM -> overall tempo scaling

## BPM design note

BPM should be treated as a continuously updated estimate, not an infallible truth. The UI should expose:
- current BPM estimate
- confidence
- tap tempo override in future versions
- half/double-time correction options in future versions

