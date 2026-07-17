import Foundation

actor VisualSceneEndpointAdapter: ShowEndpointAdapter {
    nonisolated let endpointKind: ShowEndpointKind = .visuals
    private let controller: any VisualSceneControlling
    private let clock: ShowDirectorClock
    private var lastFailure: String?

    init(
        controller: any VisualSceneControlling,
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
        guard case .recallVisualScene(_, let sceneID, _) = action else {
            return .invalid(message: "Visual scene adapter requires recallVisualScene.")
        }
        guard let target = UUID(uuidString: sceneID) else {
            return .invalid(message: "Visual scene target is not a valid UUID.")
        }
        guard await controller.visualSceneIDs().contains(target) else {
            return .invalid(message: "Visual scene \(sceneID) is not available.")
        }
        return .valid
    }

    func execute(
        _ action: EndpointAction,
        context: ShowExecutionContext
    ) async -> EndpointExecutionResult {
        _ = context
        let started = clock.now()
        guard case .recallVisualScene(_, let sceneID, _) = action else {
            return result(
                action: action,
                status: .validationFailed,
                started: started,
                message: "Visual scene adapter requires recallVisualScene."
            )
        }
        guard let target = UUID(uuidString: sceneID) else {
            return result(
                action: action,
                status: .validationFailed,
                started: started,
                message: "Visual scene target is not a valid UUID."
            )
        }

        do {
            let verified = try await MainActor.run {
                guard controller.visualSceneIDs().contains(target) else {
                    throw VisualSceneAdapterError.targetUnavailable
                }
                try controller.recallVisualScene(id: target)
                return controller.activeVisualSceneID() == target
            }
            guard verified else {
                return failedResult(
                    action: action,
                    started: started,
                    message: "Visual scene recall could not be verified."
                )
            }
            lastFailure = nil
            return result(
                action: action,
                status: .executed,
                started: started,
                message: "Scene recalled; requested fadeMs is advisory and the app transition is active."
            )
        } catch VisualSceneAdapterError.targetUnavailable {
            return result(
                action: action,
                status: .validationFailed,
                started: started,
                message: "Visual scene \(sceneID) is not available."
            )
        } catch {
            return failedResult(
                action: action,
                started: started,
                message: "Visual scene recall failed: \(error.localizedDescription)"
            )
        }
    }

    func currentHealth() async -> EndpointHealth {
        let hasScenes = await !controller.visualSceneIDs().isEmpty
        if !hasScenes {
            return EndpointHealth(
                endpoint: endpointKind,
                status: .unavailable,
                message: "No visual scenes are available.",
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

private enum VisualSceneAdapterError: Error {
    case targetUnavailable
}
