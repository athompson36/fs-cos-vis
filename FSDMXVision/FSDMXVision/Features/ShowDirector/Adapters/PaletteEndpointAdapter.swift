import Foundation

actor PaletteEndpointAdapter: ShowEndpointAdapter {
    nonisolated let endpointKind: ShowEndpointKind = .palette
    private let controller: any PaletteControlling
    private let clock: ShowDirectorClock
    private var lastFailure: String?

    init(
        controller: any PaletteControlling,
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
        guard case .applyPalette(_, let paletteID, _) = action else {
            return .invalid(message: "Palette adapter requires applyPalette.")
        }
        guard let target = UUID(uuidString: paletteID) else {
            return .invalid(message: "Palette target is not a valid UUID.")
        }
        guard await controller.paletteIDs().contains(target) else {
            return .invalid(message: "Palette \(paletteID) is not available.")
        }
        return .valid
    }

    func execute(
        _ action: EndpointAction,
        context: ShowExecutionContext
    ) async -> EndpointExecutionResult {
        _ = context
        let started = clock.now()
        guard case .applyPalette(_, let paletteID, _) = action else {
            return result(
                action: action,
                status: .validationFailed,
                started: started,
                message: "Palette adapter requires applyPalette."
            )
        }
        guard let target = UUID(uuidString: paletteID) else {
            return result(
                action: action,
                status: .validationFailed,
                started: started,
                message: "Palette target is not a valid UUID."
            )
        }

        do {
            let verified = try await MainActor.run {
                guard controller.paletteIDs().contains(target) else {
                    throw PaletteAdapterError.targetUnavailable
                }
                try controller.selectPalette(id: target)
                return controller.activePaletteID() == target
            }
            guard verified else {
                return failedResult(
                    action: action,
                    started: started,
                    message: "Palette selection could not be verified."
                )
            }
            lastFailure = nil
            return result(
                action: action,
                status: .executed,
                started: started,
                message: "Palette applied immediately; requested fadeMs is advisory."
            )
        } catch PaletteAdapterError.targetUnavailable {
            return result(
                action: action,
                status: .validationFailed,
                started: started,
                message: "Palette \(paletteID) is not available."
            )
        } catch {
            return failedResult(
                action: action,
                started: started,
                message: "Palette selection failed: \(error.localizedDescription)"
            )
        }
    }

    func currentHealth() async -> EndpointHealth {
        let hasPalettes = await !controller.paletteIDs().isEmpty
        if !hasPalettes {
            return EndpointHealth(
                endpoint: endpointKind,
                status: .unavailable,
                message: "No palettes are available.",
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

private enum PaletteAdapterError: Error {
    case targetUnavailable
}
