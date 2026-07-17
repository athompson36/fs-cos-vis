import Foundation

struct ShowExecutionContext: Equatable, Sendable {
    var showID: String?
    var commandID: String
    var cuePackageID: String?
    var runtimeRevision: UInt64
}

enum ShowActionValidationResult: Equatable, Sendable {
    case valid
    case invalid(message: String)
}

struct EndpointExecutionResult: Equatable, Sendable {
    var actionID: String
    var endpoint: ShowEndpointKind
    var status: EndpointExecutionStatus
    var durationMilliseconds: Int
    var message: String?

    init(
        actionID: String,
        endpoint: ShowEndpointKind,
        status: EndpointExecutionStatus,
        durationMilliseconds: Int,
        message: String? = nil
    ) {
        self.actionID = actionID
        self.endpoint = endpoint
        self.status = status
        self.durationMilliseconds = durationMilliseconds
        self.message = message
    }

    func asLogResult() -> EndpointActionResult {
        EndpointActionResult(
            actionID: actionID,
            endpoint: endpoint,
            status: status,
            durationMilliseconds: durationMilliseconds,
            message: message
        )
    }
}

protocol ShowEndpointAdapter: Sendable {
    var endpointKind: ShowEndpointKind { get }
    func validate(
        _ action: EndpointAction,
        context: ShowExecutionContext
    ) async -> ShowActionValidationResult
    func execute(
        _ action: EndpointAction,
        context: ShowExecutionContext
    ) async -> EndpointExecutionResult
    func currentHealth() async -> EndpointHealth
}

protocol ShowDirectorClock: Sendable {
    func now() -> Date
    func sleep(seconds: TimeInterval) async
}

struct SystemShowDirectorClock: ShowDirectorClock {
    func now() -> Date { Date() }
    func sleep(seconds: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
    }
}

protocol ShowDirectorIDGenerator: Sendable {
    func nextID(prefix: String) -> String
}

final class IncrementalShowDirectorIDGenerator: ShowDirectorIDGenerator, @unchecked Sendable {
    private let lock = NSLock()
    private var counter: UInt64 = 0

    func nextID(prefix: String) -> String {
        lock.lock()
        defer { lock.unlock() }
        counter += 1
        return "\(prefix)_\(counter)"
    }
}

actor FakeShowEndpointAdapter: ShowEndpointAdapter {
    nonisolated let endpointKind: ShowEndpointKind
    private let clock: ShowDirectorClock

    var validationResult: ShowActionValidationResult = .valid
    var executionStatus: EndpointExecutionStatus = .executed
    var executionMessage: String?
    var delaySeconds: TimeInterval = 0
    var health: EndpointHealth
    private(set) var validateCalls: [EndpointAction] = []
    private(set) var executeCalls: [EndpointAction] = []

    init(
        endpointKind: ShowEndpointKind,
        clock: ShowDirectorClock = SystemShowDirectorClock(),
        health: EndpointHealth? = nil
    ) {
        self.endpointKind = endpointKind
        self.clock = clock
        self.health = health ?? EndpointHealth(
            endpoint: endpointKind,
            status: .available,
            observedAt: clock.now()
        )
    }

    func setValidationResult(_ result: ShowActionValidationResult) {
        validationResult = result
    }

    func setExecutionStatus(_ status: EndpointExecutionStatus, message: String? = nil) {
        executionStatus = status
        executionMessage = message
    }

    func setDelaySeconds(_ seconds: TimeInterval) {
        delaySeconds = seconds
    }

    func validate(
        _ action: EndpointAction,
        context: ShowExecutionContext
    ) async -> ShowActionValidationResult {
        _ = context
        validateCalls.append(action)
        return validationResult
    }

    func execute(
        _ action: EndpointAction,
        context: ShowExecutionContext
    ) async -> EndpointExecutionResult {
        _ = context
        executeCalls.append(action)
        let delay = delaySeconds
        let status = executionStatus
        let message = executionMessage

        let started = clock.now()
        if delay > 0 {
            await clock.sleep(seconds: delay)
        }
        let ended = clock.now()
        let duration = Int(max(0, ended.timeIntervalSince(started) * 1000))
        return EndpointExecutionResult(
            actionID: action.id,
            endpoint: endpointKind,
            status: status,
            durationMilliseconds: duration,
            message: message
        )
    }

    func currentHealth() async -> EndpointHealth {
        health
    }
}
