# Lighting control strategies

FS DMX Vision stacks several **independent** ways to influence DMX. They can run at the same time; merge order matters for how the final universe is built.

## 1. Cue / scene looks

**What:** Discrete looks stored in the lighting cue list (`LightingCueDocument`). Each cue holds absolute DMX channel values (1–512), fades, and optional haze learn metadata.

**Where:** Lighting workspace → **Cues**, Live Show cue strips.

**Remote:** `SetActiveLightingCueIndex`, `NextLightingCue`, `PreviousLightingCue` (see [control-parity.md](control-parity.md), OSC in [osc-control.md](osc-control.md)).

## 2. Modulation (“sources”)

**What:** LFO, tempo, audio bands, or **HSI hue sweep** (HSV-style hue → RGB on fixtures with `.red`/`.green`/`.blue` channels) applied as **offsets** on top of the base values from the patch and active cue. Modulators can target a raw DMX address or a **patched fixture + channel index** (stored on the modulator so repatching keeps the same logical channel).

**Where:** Lighting workspace → **Tools** → Modulation.

**Stacking:** Modulation is applied after cue values in the DMX build (see `DMXUniverseBuilder`).

## 3. Remote performance (HTTP / OSC / MIDI)

**What:** External control of tempo, visualization scenes, lighting cue selection, and settings via a single command plane (`RemoteControlCommand` → `AppModel.applyRemoteCommand`).

**Where:** Built-in web UI (`GET /` when remote control is enabled), `POST /api/command`, OSC, MIDI mapping.

**Details:** [control-parity.md](control-parity.md).

## 4. Inbound DMX merge

**What:** Another console or app can contribute channels over **Art-Net/sACN** (UDP) and/or a **second USB serial interface** (Open DMX–class RX path on a different `/dev/cu.*` than DMX output). Merge mode (e.g. HTP/LTP) is defined in settings and implemented in `DMXInboundMergeLogic`. When both network and USB serial receive the same universe, the USB path uses a higher priority so a local desk can win over LAN.

**Where:** Settings → DMX → inbound merge (network + optional USB serial).

**Note:** Use separate universes or merge rules intentionally so two consoles do not fight the same channels. The classic Enttec Open DMX USB adapter is often **transmit-only**; receiving usually needs an RX-capable interface.

**USB serial framing:** Raw 250k streams are assembled using **idle-between-read** detection (see `OpenDMXFrameAssembler.defaultInterDrainIdleSeconds`) so a new packet typically starts after a gap, avoiding false alignment when many channels are `0`. Continuous back-to-back bytes without measurable USB idle still use a **start-code scan** (weaker). Adapters that **packetize in firmware** (e.g. Enttec DMX USB Pro receive mode) are easier to reason about than raw FTDI byte pipes.

---

## Interoperability with other lighting apps (e.g. Vibrio on iPad)

Third-party iPad apps typically use **network DMX** (e.g. Art-Net) and **proprietary show files**. There is **no public, stable file format** documented for importing another app’s full show into FS DMX Vision.

**Practical approaches:**

- **Protocol coexistence:** Run Vibrio (or similar) on its own universe or path; use FS DMX Vision inbound merge or separate rigs so both can operate without overwriting the same addresses.
- **Data exchange:** Use this app’s **show project JSON** or the Lighting workspace **clipboard JSON** (patch, cues, modulation bundle) as the supported interchange. For a cue-only snapshot, use `GET /api/lighting_cues` when remote control is enabled.
- **Future:** If a vendor publishes an import/export specification, a dedicated adapter could be added.

See also: [fixture-source-provenance.md](fixture-source-provenance.md) for OFL fixture data.
