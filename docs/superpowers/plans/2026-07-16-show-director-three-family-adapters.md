# Show Director Three-Family Adapters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Connect the Show Director engine to real visual-scene, palette, and lighting-cue app services through verified main-actor adapters and one AppModel-owned runtime engine.

**Architecture:** Three actor-isolated adapters depend on narrow `@MainActor` control protocols. `AppModel` conforms to those protocols and owns a race-safe, long-lived `ShowDirectorEngine`; the existing engine remains responsible for ordering, timeout, partial failure, logging, and runtime state.

**Tech Stack:** Swift 6, macOS 14, Foundation, Combine/`@Published`, Swift concurrency actors and global actors, XCTest, XcodeGen.

## Global Constraints

- Follow `docs/superpowers/specs/2026-07-16-show-director-three-family-adapters-design.md`.
- Preserve existing scene, palette, and lighting-cue UUID identities.
- Do not call `AppModel.applyRemoteCommand` from adapters.
- Keep app mutations and verification on `MainActor`.
- Keep adapters `Sendable`, timeline-neutral, and free of authored/runtime ownership.
- Keep engine execution serial and preserve existing five-second timeout and JSONL logging.
- Visual/palette `fadeMs` is advisory; lighting uses persisted `fadeSeconds`.
- Do not add UI, video, overlay, recording, utility, OBS, remote, or DJ functionality.
- Do not commit unless the user explicitly requests it.

---

## Task 1: Extend the typed lighting action contract

**Files:**
- Modify: `FSDMXVision/FSDMXVision/Features/ShowDirector/Models/EndpointAction.swift`
- Modify: `FSDMXVision/FSDMXVisionTests/ShowDirectorModelTests.swift`

**Interfaces:**
- Produces: `EndpointAction.recallLightingCue(id: String, cueID: String)`
- Wire format: `{"endpoint":"lighting","type":"recallCue","cueId":"<UUID>"}`
- Preserves: existing `recallLightingScene` encode/decode behavior

- [ ] **Step 1: Write failing Codable tests**

Add tests that assert the new action round-trips and uses `cueId`:

```swift
func testLightingCueAction_roundTripsWithExplicitCueID() throws {
    let action = EndpointAction.recallLightingCue(
        id: "action_light_intro",
        cueID: "00000000-0000-0000-0000-000000000001"
    )
    let data = try ShowDirectorJSON.makeEncoder().encode(action)
    let json = try XCTUnwrap(String(data: data, encoding: .utf8))
    XCTAssertTrue(json.contains(#""type" : "recallCue""#))
    XCTAssertTrue(json.contains(#""cueId" : "00000000-0000-0000-0000-000000000001""#))
    XCTAssertEqual(try ShowDirectorJSON.makeDecoder().decode(EndpointAction.self, from: data), action)
}

func testLegacyLightingSceneAction_stillRoundTrips() throws {
    let action = EndpointAction.recallLightingScene(
        id: "legacy",
        sceneID: "legacy-scene",
        fadeMilliseconds: 250
    )
    let data = try ShowDirectorJSON.makeEncoder().encode(action)
    XCTAssertEqual(try ShowDirectorJSON.makeDecoder().decode(EndpointAction.self, from: data), action)
}
```

- [ ] **Step 2: Run the focused tests and confirm failure**

```bash
xcodebuild test -project FSDMXVision.xcodeproj -scheme FSDMXVision \
  -destination 'platform=macOS' \
  -only-testing:FSDMXVisionTests/ShowDirectorModelTests
```

Expected: compile failure because `recallLightingCue` is absent.

- [ ] **Step 3: Add the enum case and computed-property coverage**

Update every exhaustive switch:

```swift
case recallLightingCue(id: String, cueID: String)
```

- `id` returns its associated `id`.
- `endpointKind` returns `.lighting`.
- `typeName` returns `"recallCue"`.

- [ ] **Step 4: Extend custom Codable**

Add `cueID = "cueId"` to `CodingKeys`.

Decode:

```swift
case ("lighting", "recallCue"):
    self = .recallLightingCue(
        id: id,
        cueID: try c.decode(String.self, forKey: .cueID)
    )
```

Encode:

```swift
case .recallLightingCue(_, let cueID):
    try c.encode(cueID, forKey: .cueID)
```

- [ ] **Step 5: Run focused tests**

Expected: all `ShowDirectorModelTests` pass.

---

## Task 2: Define endpoint controls and implement real adapters

**Files:**
- Create: `FSDMXVision/FSDMXVision/Features/ShowDirector/Adapters/ShowDirectorEndpointControls.swift`
- Create: `FSDMXVision/FSDMXVision/Features/ShowDirector/Adapters/VisualSceneEndpointAdapter.swift`
- Create: `FSDMXVision/FSDMXVision/Features/ShowDirector/Adapters/PaletteEndpointAdapter.swift`
- Create: `FSDMXVision/FSDMXVision/Features/ShowDirector/Adapters/LightingCueEndpointAdapter.swift`
- Create: `FSDMXVision/FSDMXVisionTests/ShowDirectorRealAdapterTests.swift`

**Interfaces:**
- Consumes: `ShowEndpointAdapter`, `ShowDirectorClock`, `EndpointAction`
- Produces:
  - `VisualSceneControlling`
  - `PaletteControlling`
  - `LightingCueControlling`
  - Three concrete adapter actors

- [ ] **Step 1: Add control protocols**

Use exact signatures:

```swift
@MainActor
protocol VisualSceneControlling: AnyObject, Sendable {
    func visualSceneIDs() -> [UUID]
    func activeVisualSceneID() -> UUID?
    func recallVisualScene(id: UUID) throws
}

@MainActor
protocol PaletteControlling: AnyObject, Sendable {
    func paletteIDs() -> [UUID]
    func activePaletteID() -> UUID?
    func selectPalette(id: UUID) throws
}

@MainActor
protocol LightingCueControlling: AnyObject, Sendable {
    func lightingCueIDs() -> [UUID]
    func activeLightingCueID() -> UUID?
    func recallLightingCue(id: UUID) throws
    func lightingCueFadeSeconds(id: UUID) -> Double?
}
```

- [ ] **Step 2: Write actor-safe test controllers**

In `ShowDirectorRealAdapterTests.swift`, add small `@MainActor final class` fakes for each protocol. Each fake stores IDs, active ID, optional thrown error, and a verification-override ID.

- [ ] **Step 3: Write failing visual adapter tests**

Cover:

- `.recallVisualScene` validation success.
- Wrong action, malformed UUID, and missing UUID validation failure.
- Successful execution changes and verifies target.
- Verification mismatch returns `.failed`.
- Empty/nonempty health.
- Failure degrades health; success restores availability.
- Exact message:
  `Scene recalled; requested fadeMs is advisory and the app transition is active.`

- [ ] **Step 4: Implement `VisualSceneEndpointAdapter`**

Use an actor:

```swift
actor VisualSceneEndpointAdapter: ShowEndpointAdapter {
    nonisolated let endpointKind: ShowEndpointKind = .visuals
    private let controller: any VisualSceneControlling
    private let clock: ShowDirectorClock
    private var lastFailure: String?
}
```

Parse UUID during validation. During execution:

1. Capture `let started = clock.now()`.
2. Call `try await controller.recallVisualScene(id:)`.
3. Verify with `await controller.activeVisualSceneID()`.
4. Calculate `durationMilliseconds` from `clock.now().timeIntervalSince(started)`.
5. Update `lastFailure` and return the exact policy message.

- [ ] **Step 5: Write and implement equivalent palette tests/adapter**

Exact success message:

```text
Palette applied immediately; requested fadeMs is advisory.
```

Use `.applyPalette` and `.palette`.

- [ ] **Step 6: Write and implement equivalent lighting tests/adapter**

Accept only `.recallLightingCue`. Resolve persisted fade through `lightingCueFadeSeconds(id:)`.

Exact success message format:

```swift
"Lighting cue recalled using its persisted fade of \(formattedSeconds)s."
```

Use deterministic formatting without locale-dependent commas (for example `String(format: "%.3g", seconds)` with POSIX locale).

- [ ] **Step 7: Run adapter tests**

```bash
bash scripts/bootstrap-xcodegen.sh
xcodebuild test -project FSDMXVision.xcodeproj -scheme FSDMXVision \
  -destination 'platform=macOS' \
  -only-testing:FSDMXVisionTests/ShowDirectorRealAdapterTests
```

Expected: all adapter tests pass with no Swift 6 concurrency diagnostics.

---

## Task 3: Add AppModel endpoint protocol conformances

**Files:**
- Modify: `FSDMXVision/FSDMXVision/App/AppModel.swift`
- Modify: `FSDMXVision/FSDMXVisionTests/AppModelTests.swift`

**Interfaces:**
- Consumes: the three control protocols from Task 2
- Produces: awaitable and verifiable real mutations for adapters

- [ ] **Step 1: Write failing AppModel integration tests**

Add `@MainActor` tests for:

1. `recallVisualScene(id:)` selects the target UUID and starts transition state when changing scenes.
2. `selectPalette(id:)` updates `selectedPaletteID`.
3. `recallLightingCue(id:)` resolves UUID and updates `activeCueIndex`.
4. Missing targets throw a typed `ShowDirectorEndpointControlError.targetNotFound`.

- [ ] **Step 2: Add a shared typed control error**

In `ShowDirectorEndpointControls.swift`:

```swift
enum ShowDirectorEndpointControlError: Error, LocalizedError, Equatable {
    case targetNotFound(endpoint: ShowEndpointKind, id: UUID)
    case verificationFailed(endpoint: ShowEndpointKind, id: UUID)
    case persistenceFailed(endpoint: ShowEndpointKind, message: String)
}
```

Provide explicit operator-facing descriptions.

- [ ] **Step 3: Conform `AppModel` in `AppModel.swift`**

Declare:

```swift
extension AppModel: VisualSceneControlling, PaletteControlling, LightingCueControlling { ... }
```

Keep the extension in `AppModel.swift` so private members remain accessible.

Visual mutation:

- Resolve target index.
- Set `transitionState` exactly like `performJumpToScene`.
- Update `sceneManager.currentIndex`.
- Call `syncRendererFromScene()`.
- Call throwing `persistScenes()` and map errors to `.persistenceFailed`.

Palette mutation:

- Resolve target from `palettes`.
- Set `selectedPaletteID`.
- Call `syncRendererFromScene()`.

Lighting mutation:

- Snapshot `lightingCueDocument.cues` under `lightingDMXLock`.
- Resolve UUID to index.
- Call `setActiveLightingCueIndex(index)`.
- Verify UUID through a fresh locked snapshot.

- [ ] **Step 4: Run AppModel tests**

```bash
xcodebuild test -project FSDMXVision.xcodeproj -scheme FSDMXVision \
  -destination 'platform=macOS' \
  -only-testing:FSDMXVisionTests/AppModelTests
```

Expected: all AppModel tests pass.

---

## Task 4: Add AppModel-owned runtime lifecycle

**Files:**
- Modify: `FSDMXVision/FSDMXVision/App/AppModel.swift`
- Create: `FSDMXVision/FSDMXVisionTests/ShowDirectorRuntimeLifecycleTests.swift`

**Interfaces:**
- Produces:
  - `ShowDirectorRuntimeStatus`
  - `showDirectorEngine`
  - race-safe `configureShowDirectorRuntime(graph:packageRoot:)`

- [ ] **Step 1: Write failing lifecycle tests**

Cover:

- Valid graph transitions status to `.ready` and installs an engine.
- Nil graph yields `.unconfigured` and clears engine.
- Rejected load yields `.failed(message:)` and clears engine.
- Starting configuration B before delayed A completes installs only B.

Use an injected graph-loader closure in tests so races are deterministic.

The exact injection seam is an internal stored closure on `AppModel`:

```swift
var showDirectorGraphLoader:
    @Sendable (ShowDirectorEngine, ShowDirectorGraph, String) async -> ShowDirectorSubmitResult = {
        engine, graph, commandID in
        await engine.submit(.loadShow(commandID: commandID, graph: graph))
    }
```

Production uses the default. Tests replace it with a closure suspended on a controllable continuation, allowing configuration A to finish after configuration B.

- [ ] **Step 2: Add runtime status**

In `AppModel.swift`:

```swift
enum ShowDirectorRuntimeStatus: Equatable, Sendable {
    case unconfigured
    case loading
    case ready
    case failed(message: String)
}
```

Add:

```swift
@Published private(set) var showDirectorRuntimeStatus: ShowDirectorRuntimeStatus = .unconfigured
private(set) var showDirectorEngine: ShowDirectorEngine?
private var showDirectorConfigurationTask: Task<Void, Never>?
private var showDirectorConfigurationGeneration: UInt64 = 0
var showDirectorGraphLoader:
    @Sendable (ShowDirectorEngine, ShowDirectorGraph, String) async -> ShowDirectorSubmitResult
```

- [ ] **Step 3: Add adapter/engine construction**

Create the engine with:

```swift
let adapters: [ShowEndpointAdapter] = [
    VisualSceneEndpointAdapter(controller: self),
    PaletteEndpointAdapter(controller: self),
    LightingCueEndpointAdapter(controller: self),
]
let engine = ShowDirectorEngine(
    adapters: adapters,
    packageRoot: packageRoot
)
```

Submit `.loadShow(commandID: "app_load_<generation>", graph: graph)`.

- [ ] **Step 4: Make configuration race-safe**

On each configuration:

1. Cancel prior task.
2. Increment generation.
3. Set `.loading`.
4. Build/load engine.
5. Before installation, check task cancellation and generation equality on `MainActor`.
6. Install only the latest accepted engine.

- [ ] **Step 5: Wire package load and graph replacement**

- `loadShowProject`: after optional graph load, configure runtime with the package folder.
- Legacy/no graph: configure nil.
- Invalid graph: clear runtime and set failed using the package-load message.
- `replaceShowDirectorGraph`: invoke the same configuration path using current package root.

- [ ] **Step 6: Run lifecycle and existing package tests**

```bash
xcodebuild test -project FSDMXVision.xcodeproj -scheme FSDMXVision \
  -destination 'platform=macOS' \
  -only-testing:FSDMXVisionTests/ShowDirectorRuntimeLifecycleTests \
  -only-testing:FSDMXVisionTests/ShowProjectAndContextTests
```

Expected: all selected tests pass.

---

## Task 5: Prove three-family real-adapter acceptance

**Files:**
- Create: `FSDMXVision/FSDMXVisionTests/ShowDirectorThreeFamilyAcceptanceTests.swift`
- Modify: `FSDMXVision/FSDMXVisionTests/ShowDirectorValidationTests.swift` if fixture helpers need typed lighting cues

**Interfaces:**
- Consumes: all Task 1–4 interfaces
- Produces: SD-M4 slice acceptance evidence

- [ ] **Step 1: Build deterministic main-actor controllers**

Create scene, palette, and lighting UUIDs. Build controllers that contain those targets and verify actual state mutation.

- [ ] **Step 2: Build one ordered cue package**

```swift
let cue = CuePackage(
    id: "cue_three_family",
    name: "Three Family",
    actions: [
        .recallVisualScene(id: "action_visual", sceneID: sceneID.uuidString, fadeMilliseconds: 500),
        .applyPalette(id: "action_palette", paletteID: paletteID.uuidString, fadeMilliseconds: 500),
        .recallLightingCue(id: "action_lighting", cueID: lightingCueID.uuidString),
    ]
)
```

Insert it into a valid `ShowDirectorGraph`.

- [ ] **Step 3: Execute through the real adapters**

Create a temporary package root and engine, submit `loadShow`, then submit `go`.

- [ ] **Step 4: Assert acceptance**

- All three active UUIDs match target.
- One execution log entry contains action IDs in the original order.
- All three statuses are `.executed`.
- Runtime revision increased.
- `currentHealth()` for all three adapters returns `.available`.

- [ ] **Step 5: Add partial-failure coverage**

Make palette verification fail while visual and lighting succeed. Assert the log statuses are `[.executed, .failed, .executed]`.

- [ ] **Step 6: Run Show Director tests**

```bash
xcodebuild test -project FSDMXVision.xcodeproj -scheme FSDMXVision \
  -destination 'platform=macOS' \
  -only-testing:FSDMXVisionTests/ShowDirectorModelTests \
  -only-testing:FSDMXVisionTests/ShowDirectorRealAdapterTests \
  -only-testing:FSDMXVisionTests/ShowDirectorRuntimeLifecycleTests \
  -only-testing:FSDMXVisionTests/ShowDirectorThreeFamilyAcceptanceTests
```

Expected: all selected tests pass.

---

## Task 6: Documentation and full verification

**Files:**
- Modify: `docs/production-and-show-director-todo.md`
- Modify: `docs/07-roadmap.md`
- Modify: `docs/audit-execution-record.md`
- Modify: `docs/production-readiness-checklist.md`

- [ ] **Step 1: Update SD-M4 tracking honestly**

Mark SD-4.1, SD-4.2, and the lighting-cue portion of SD-4.3 complete. Mark SD-4.9 complete only after the three-family acceptance test passes. Leave safety expansion, video, overlay, recording, utility, and full endpoint health tracking open/partial.

- [ ] **Step 2: Update test-count evidence**

After the full suite, update references to the actual executed test count and date. Do not predict the number.

- [ ] **Step 3: Run package smoke**

```bash
bash scripts/ci/smoke-show-package.sh
```

Expected: two selected package tests pass.

- [ ] **Step 4: Run full suite**

```bash
xcodebuild test -project FSDMXVision.xcodeproj -scheme FSDMXVision \
  -destination 'platform=macOS'
```

Expected: `** TEST SUCCEEDED **`, zero failures.

- [ ] **Step 5: Run final hygiene**

```bash
git diff --check
```

Read IDE diagnostics for all edited Swift files; expected: no new errors or warnings.

- [ ] **Step 6: Review the entire diff**

Confirm:

- No action uses cue indices as persisted identity.
- No adapter calls `applyRemoteCommand`.
- No adapter reports success before read-back verification.
- No deferred SD-M4 items are marked complete.
- The implementation plan file itself remains unchanged during execution.
