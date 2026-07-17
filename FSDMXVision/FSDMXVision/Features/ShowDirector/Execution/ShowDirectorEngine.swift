import Foundation

struct ShowDirectorSubmitResult: Equatable, Sendable {
    var disposition: ShowDirectorCommandDisposition
    var runtime: ShowRuntimeState
    var duplicated: Bool
}

actor ShowDirectorEngine {
    static let defaultActionTimeoutSeconds: TimeInterval = 5
    static let processedCommandCacheLimit = 512

    private var reducerState = ShowDirectorReducerState()
    private var adapters: [ShowEndpointKind: ShowEndpointAdapter]
    private var processedCommands: [String: ShowDirectorCommandDisposition] = [:]
    private var processedOrder: [String] = []
    private let clock: ShowDirectorClock
    private let idGenerator: ShowDirectorIDGenerator
    private let packageRoot: URL?
    private let actionTimeoutSeconds: TimeInterval
    private var continuations: [UUID: AsyncStream<ShowRuntimeState>.Continuation] = [:]

    init(
        adapters: [ShowEndpointAdapter] = [],
        clock: ShowDirectorClock = SystemShowDirectorClock(),
        idGenerator: ShowDirectorIDGenerator = IncrementalShowDirectorIDGenerator(),
        packageRoot: URL? = nil,
        actionTimeoutSeconds: TimeInterval = ShowDirectorEngine.defaultActionTimeoutSeconds
    ) {
        var map: [ShowEndpointKind: ShowEndpointAdapter] = [:]
        for adapter in adapters {
            map[adapter.endpointKind] = adapter
        }
        self.adapters = map
        self.clock = clock
        self.idGenerator = idGenerator
        self.packageRoot = packageRoot
        self.actionTimeoutSeconds = actionTimeoutSeconds
    }

    func runtimeState() -> ShowRuntimeState {
        reducerState.runtime
    }

    func subscribe() -> AsyncStream<ShowRuntimeState> {
        let id = UUID()
        let initial = reducerState.runtime
        return AsyncStream { continuation in
            continuations[id] = continuation
            continuation.yield(initial)
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id) }
            }
        }
    }

    func submit(_ command: ShowDirectorCommand) async -> ShowDirectorSubmitResult {
        if let cached = processedCommands[command.commandID] {
            return ShowDirectorSubmitResult(
                disposition: cached,
                runtime: reducerState.runtime,
                duplicated: true
            )
        }

        let reduction = ShowDirectorReducer.reduce(state: reducerState, command: command)
        reducerState = reduction.state
        remember(commandID: command.commandID, disposition: reduction.disposition)

        if case .accepted = reduction.disposition {
            await executeEffects(reduction.effects, originatingCommandID: command.commandID)
        } else if reduction.effects.contains(.publishState) {
            publish()
        }

        return ShowDirectorSubmitResult(
            disposition: reduction.disposition,
            runtime: reducerState.runtime,
            duplicated: false
        )
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }

    private func remember(commandID: String, disposition: ShowDirectorCommandDisposition) {
        if processedCommands[commandID] == nil {
            processedOrder.append(commandID)
        }
        processedCommands[commandID] = disposition
        while processedOrder.count > Self.processedCommandCacheLimit {
            let oldest = processedOrder.removeFirst()
            processedCommands.removeValue(forKey: oldest)
        }
    }

    private func executeEffects(
        _ effects: [ShowDirectorEffect],
        originatingCommandID: String
    ) async {
        for effect in effects {
            switch effect {
            case .publishState:
                publish()
            case .executeCuePackage(let commandID, let cuePackageID):
                await executeCuePackage(commandID: commandID, cuePackageID: cuePackageID)
            case .executeSafetyAction(let commandID, let action):
                await executeSafetyAction(commandID: commandID, action: action)
            }
        }
        _ = originatingCommandID
    }

    private func executeCuePackage(commandID: String, cuePackageID: String) async {
        let revisionBefore = reducerState.runtime.revision
        guard let cue = reducerState.graph?.cuePackagesByID[cuePackageID] else {
            let result = EndpointActionResult(
                actionID: "missing_cue",
                endpoint: .utility,
                status: .validationFailed,
                durationMilliseconds: 0,
                message: "Cue package \"\(cuePackageID)\" is missing."
            )
            await finishExecution(
                commandID: commandID,
                cuePackageID: cuePackageID,
                results: [result],
                revisionBefore: revisionBefore
            )
            return
        }

        var results: [EndpointActionResult] = []
        for action in cue.actions {
            results.append(await runAction(action, commandID: commandID, cuePackageID: cuePackageID))
        }
        await finishExecution(
            commandID: commandID,
            cuePackageID: cuePackageID,
            results: results,
            revisionBefore: revisionBefore
        )
    }

    private func executeSafetyAction(commandID: String, action: EndpointAction) async {
        let revisionBefore = reducerState.runtime.revision
        let result = await runAction(action, commandID: commandID, cuePackageID: nil)
        await finishExecution(
            commandID: commandID,
            cuePackageID: nil,
            results: [result],
            revisionBefore: revisionBefore
        )
    }

    private func runAction(
        _ action: EndpointAction,
        commandID: String,
        cuePackageID: String?
    ) async -> EndpointActionResult {
        let context = ShowExecutionContext(
            showID: reducerState.runtime.showID,
            commandID: commandID,
            cuePackageID: cuePackageID,
            runtimeRevision: reducerState.runtime.revision
        )
        guard let adapter = adapters[action.endpointKind] else {
            return EndpointActionResult(
                actionID: action.id,
                endpoint: action.endpointKind,
                status: .unsupported,
                durationMilliseconds: 0,
                message: "No adapter registered for \(action.endpointKind.rawValue)."
            )
        }

        let validation = await adapter.validate(action, context: context)
        if case .invalid(let message) = validation {
            return EndpointActionResult(
                actionID: action.id,
                endpoint: action.endpointKind,
                status: .validationFailed,
                durationMilliseconds: 0,
                message: message
            )
        }

        let started = clock.now()
        let result: EndpointExecutionResult
        do {
            result = try await withTimeout(seconds: actionTimeoutSeconds) {
                await adapter.execute(action, context: context)
            }
        } catch {
            let duration = Int(max(0, clock.now().timeIntervalSince(started) * 1000))
            return EndpointActionResult(
                actionID: action.id,
                endpoint: action.endpointKind,
                status: .timedOut,
                durationMilliseconds: duration,
                message: "Action timed out after \(Int(actionTimeoutSeconds))s."
            )
        }
        return result.asLogResult()
    }

    private func finishExecution(
        commandID: String,
        cuePackageID: String?,
        results: [EndpointActionResult],
        revisionBefore: UInt64
    ) async {
        let reduction = ShowDirectorReducer.reduce(
            state: reducerState,
            command: .cueExecutionFinished(
                commandID: commandID,
                cuePackageID: cuePackageID,
                results: results
            )
        )
        reducerState = reduction.state
        // Completion feedback should not consume the external command-id dedupe slot as a new command.
        publish()

        if let packageRoot {
            let entry = ExecutionLogEntry(
                id: idGenerator.nextID(prefix: "log"),
                timestamp: clock.now(),
                commandID: commandID,
                cuePackageID: cuePackageID,
                results: results,
                runtimeRevisionBefore: revisionBefore,
                runtimeRevisionAfter: reducerState.runtime.revision
            )
            try? ShowDirectorExecutionLogStore.append(entry, to: packageRoot)
        }
    }

    private func publish() {
        let snapshot = reducerState.runtime
        for continuation in continuations.values {
            continuation.yield(snapshot)
        }
    }

    private func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @Sendable @escaping () async -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                await operation()
            }
            group.addTask {
                await self.clock.sleep(seconds: seconds)
                throw CancellationError()
            }
            guard let first = try await group.next() else {
                throw CancellationError()
            }
            group.cancelAll()
            return first
        }
    }
}
