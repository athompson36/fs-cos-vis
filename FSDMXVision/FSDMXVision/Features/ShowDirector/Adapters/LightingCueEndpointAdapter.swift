import Foundation

actor LightingCueEndpointAdapter: ShowEndpointAdapter {
    nonisolated let endpointKind: ShowEndpointKind = .lighting
    private let controller: any LightingCueControlling
    private let clock: ShowDirectorClock
    private var lastFailure: String?

    init(
        controller: any LightingCueControlling,
        clock: ShowDirectorClock = SystemShowDirectorClock()
    ) {
        self.controller = controller
        self.clock = clock
    }

    func validate(
        _ action: EndpointAction,
        context: ShowExecutionContext
    ) async -> ShowActionValidationResult {
        _ = context
        guard case .recallLightingCue(_, let cueID) = action else {
            return .invalid(message: "Lighting cue adapter requires recallLightingCue.")
        }
        guard let target = UUID(uuidString: cueID) else {
            return .invalid(message: "Lighting cue target is not a valid UUID.")
        }
        guard await controller.lightingCueIDs().contains(target) else {
            return .invalid(message: "Lighting cue \(cueID) is not available.")
        }
        return .valid
    }

    func execute(
        _ action: EndpointAction,
        context: ShowExecutionContext
    ) async -> EndpointExecutionResult {
        _ = context
        let started = clock.now()
        guard case .recallLightingCue(_, let cueID) = action else {
            return result(
                action: action,
                status: .validationFailed,
                started: started,
                message: "Lighting cue adapter requires recallLightingCue."
            )
        }
        guard let target = UUID(uuidString: cueID) else {
            return result(
                action: action,
                status: .validationFailed,
                started: started,
                message: "Lighting cue target is not a valid UUID."
            )
        }

        do {
            let (verified, fadeSeconds) = try await MainActor.run {
                guard controller.lightingCueIDs().contains(target) else {
                    throw LightingCueAdapterError.targetUnavailable
                }
                guard let fadeSeconds = controller.lightingCueFadeSeconds(id: target) else {
                    throw LightingCueAdapterError.fadeUnavailable
                }
                try controller.recallLightingCue(id: target)
                return (controller.activeLightingCueID() == target, fadeSeconds)
            }
            guard verified else {
                return failedResult(
                    action: action,
                    started: started,
                    message: "Lighting cue recall could not be verified."
                )
            }
            lastFailure = nil
            let formattedSeconds = String(
                format: "%.3g",
                locale: Locale(identifier: "en_US_POSIX"),
                fadeSeconds
            ).lowercased()
            return result(
                action: action,
                status: .executed,
                started: started,
                message: "Lighting cue recalled using its persisted fade of \(formattedSeconds)s."
            )
        } catch LightingCueAdapterError.targetUnavailable {
            return result(
                action: action,
                status: .validationFailed,
                started: started,
                message: "Lighting cue \(cueID) is not available."
            )
        } catch LightingCueAdapterError.fadeUnavailable {
            return failedResult(
                action: action,
                started: started,
                message: "Lighting cue persisted fade could not be resolved."
            )
        } catch {
            return failedResult(
                action: action,
                started: started,
                message: "Lighting cue recall failed: \(error.localizedDescription)"
            )
        }
    }

    func currentHealth() async -> EndpointHealth {
        let hasCues = await !controller.lightingCueIDs().isEmpty
        if !hasCues {
            return EndpointHealth(
                endpoint: endpointKind,
                status: .unavailable,
                message: "No lighting cues are available.",
                observedAt: clock.now()
            )
        }
        return EndpointHealth(
            endpoint: endpointKind,
            status: lastFailure == nil ? .available : .degraded,
            message: lastFailure,
            observedAt: clock.now()
        )
    }

    private func failedResult(
        action: EndpointAction,
        started: Date,
        message: String
    ) -> EndpointExecutionResult {
        lastFailure = message
        return result(action: action, status: .failed, started: started, message: message)
    }

    private func result(
        action: EndpointAction,
        status: EndpointExecutionStatus,
        started: Date,
        message: String?
    ) -> EndpointExecutionResult {
        EndpointExecutionResult(
            actionID: action.id,
            endpoint: endpointKind,
            status: status,
            durationMilliseconds: Int(max(0, clock.now().timeIntervalSince(started) * 1_000)),
            message: message
        )
    }
}

private enum LightingCueAdapterError: Error {
    case targetUnavailable
    case fadeUnavailable
}
