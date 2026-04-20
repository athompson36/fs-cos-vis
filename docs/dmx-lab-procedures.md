# DMX lab / field procedures (Gate 3a–c)

**Purpose:** Repeatable operator steps for **production checklist** sub-gates that need hardware or a third-party receiver. Completing a row in [`production-readiness-checklist.md`](production-readiness-checklist.md) still requires **recording results** (notes, photos, or linked tickets).

**Background:** Transport behavior and honest scope — [`lighting-roadmap.md`](lighting-roadmap.md) § *Production readiness — transport certification* and Section I in [`todo-full-implementation.md`](todo-full-implementation.md).

---

## Gate 3a — Outbound (Art-Net / sACN)

**Goal:** Confirm **universe addressing** and **send rate** vs app diagnostics (**pkt/tick**, extended output diagnostics in Settings / Lighting).

1. Enable **network DMX output** in Settings (Art-Net or sACN as appropriate). Set **network universe offset** and any mode flags your rig needs.
2. Point a **known-good receiver** (desk, node, or sACN viewer) at the same LAN; subscribe to the **wire universe** you expect from offset math.
3. In the app, open **Lighting** / **Settings** diagnostics for DMX output — note **packets per tick** (or equivalent) while output is active.
4. **Pass criteria (document):** Receiver sees the same universe index and sensible channel levels; pkt/tick matches expectations for your frame rate and universe count; no unexplained dropouts on a quiet network.

Repeat for **sACN** if you use it: outbound framing is covered in unit tests (`DMXNetworkPacketBuilder.makeSACNPacket`); the lab step confirms **your** receivers and switching gear.

---

## Gate 3b.2 — Field log (competing inbound sources)

**Goal:** When two or more sources can hit the same universe, observe **priority / merge** behavior.

1. Enable **inbound DMX**; set **merge mode** (HTP vs LTP) per [`lighting-roadmap.md`](lighting-roadmap.md).
2. Introduce **two sources** (e.g. two sACN senders with different **E1.31 priority**, or Art-Net + sACN) on a test universe.
3. **Log (freeform):** date, hardware, merge mode, which source “won” when both active, and whether behavior matched expectations. Link any bug tickets.

Implementation reference: `DMXInboundMergeLogic`, `AppModel` inbound map, `DMXInputService`.

---

## Gate 3c.2 — Extended sACN PDUs in the field

**Goal:** If your environment emits **sync** or **universe discovery** packets, capture that the app **counts** them (diagnostics) without claiming full protocol compliance.

1. With inbound **sACN** on, open **Settings** receiver diagnostics — note **sync** and **discovery** packet counts and any parsed **sync universe** / **UDL** hints (see `SettingsView` inbound diagnostics string).
2. **Log:** What gear was on the wire; whether counts increased when expected; screenshots optional.

---

## Sign-off template

| Sub-gate | Date | Environment | Result / link |
|----------|------|-------------|----------------|
| 3a.1 | 2026-04-19 | **No physical receiver** — automated baseline only | **Deferred (hardware):** full macOS `xcodebuild test` passed (152 tests). Art-Net encode/decode covered by `DMXOutputServiceTests` (e.g. `testArtNetPacket_builderEncodesHeaderAndUniverse`, `testInboundDMXPacketDecoder_artnetPacketRoundTrip`). **Not done:** universe/rate vs **pkt/tick** with a real receiver. |
| 3a.2 | 2026-04-19 | Same | **Deferred (hardware):** sACN full E1.31 frame + inbound decode covered in tests (`testSACNPacket_builderEmitsFullE131Frame`, `testInboundDMXPacketDecoder_sacnPacketRoundTrip`, etc.). **Not done:** receiver on LAN. |
| 3b.2 | 2026-04-19 | **No dual sources on wire** | **Deferred (field):** merge/priority logic covered by `DMXInboundMergeLogic` tests + `testInboundDMXPacketDecoder_sacnPriorityFieldDecoded`. **Not done:** two live sources + operator log. |
| 3c.2 | 2026-04-19 | **No field gear emitting extended PDUs** | **Deferred (field):** classifier tests pass (`testSACNE131InboundClassifier_*`, hex fixtures). **Not done:** live sync/discovery counts in Settings with real traffic. |

---

## Run record — automated baseline (2026-04-19)

Executed in-repo (no GUI, no DMX hardware):

```bash
xcodegen generate
xcodebuild test -project FSDMXVision.xcodeproj -scheme FSDMXVision -destination 'platform=macOS'
```

**Outcome:** `TEST SUCCEEDED` — **152** tests, **0** failures.

**DMX-related suites (non-exhaustive):** `DMXOutputServiceTests`, `DMXUniverseBuilderTests`, plus DMX-adjacent cases in `ControlBusTests`, `ModelCodableTests` (DMX settings).

**Interpretation:** This satisfies **deterministic / CI** evidence for packet formats, inbound decode, merge rules, extended PDU classification, and profiler math. It does **not** close **3a–3c** lab/field rows in [`production-readiness-checklist.md`](production-readiness-checklist.md); repeat the manual steps above when a receiver and LAN are available, then update this table or link a ticket.
