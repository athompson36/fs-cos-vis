import Foundation

enum ShowDirectorReducer {
    static func reduce(
        state: ShowDirectorReducerState,
        command: ShowDirectorCommand
    ) -> ShowDirectorReduction {
        guard !command.commandID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ShowDirectorReduction(
                state: state,
                disposition: .rejected(reason: "commandID must be non-empty.")
            )
        }

        switch command {
        case .loadShow(_, let graph):
            return loadShow(state: state, commandID: command.commandID, graph: graph)
        case .selectSetlistItem(_, let itemID):
            return selectSetlistItem(state: state, commandID: command.commandID, itemID: itemID)
        case .go:
            return go(state: state, commandID: command.commandID)
        case .previous:
            return previous(state: state, commandID: command.commandID)
        case .next:
            return next(state: state, commandID: command.commandID)
        case .hold:
            return hold(state: state, commandID: command.commandID)
        case .resume:
            return resume(state: state, commandID: command.commandID)
        case .repeatSection:
            return repeatSection(state: state, commandID: command.commandID)
        case .jumpToSection(_, let sectionID):
            return jumpToSection(state: state, commandID: command.commandID, sectionID: sectionID)
        case .firePresetNow(_, let presetID):
            return firePresetNow(state: state, commandID: command.commandID, presetID: presetID)
        case .insertPresetNext(_, let presetID):
            return queueOverride(
                state: state,
                commandID: command.commandID,
                presetID: presetID,
                placement: .insertNext
            )
        case .replaceUpcomingCue(_, let presetID):
            return queueOverride(
                state: state,
                commandID: command.commandID,
                presetID: presetID,
                placement: .replaceUpcoming
            )
        case .undo:
            return undo(state: state, commandID: command.commandID)
        case .park:
            return park(state: state, commandID: command.commandID)
        case .blackoutLighting:
            return safety(
                state: state,
                commandID: command.commandID,
                action: .blackoutLighting(id: "safety_blackout_lighting")
            )
        case .blackoutVideo:
            return safety(
                state: state,
                commandID: command.commandID,
                action: .blackoutVideo(id: "safety_blackout_video")
            )
        case .restoreSafeLook:
            return safety(
                state: state,
                commandID: command.commandID,
                action: .restoreSafeLook(id: "safety_restore_safe_look")
            )
        case .endpointHealthChanged(_, let health):
            return endpointHealthChanged(state: state, commandID: command.commandID, health: health)
        case .cueExecutionFinished(_, let cuePackageID, let results):
            return cueExecutionFinished(
                state: state,
                commandID: command.commandID,
                cuePackageID: cuePackageID,
                results: results
            )
        }
    }

    // MARK: - Commands

    private static func loadShow(
        state: ShowDirectorReducerState,
        commandID: String,
        graph: ShowDirectorGraph
    ) -> ShowDirectorReduction {
        guard let setlist = graph.setlistsByID[graph.show.defaultSetlistID],
              let firstItem = setlist.items.first,
              let song = graph.songsByID[firstItem.songScoreID],
              let firstSection = song.sections.first
        else {
            return ShowDirectorReduction(
                state: state,
                disposition: .rejected(reason: "Show graph is missing a default setlist item/section.")
            )
        }

        var next = pushingUndo(state)
        next.graph = graph
        next.queuedOverride = nil
        next.runtime.showID = graph.show.id
        next.runtime.activeSetlistID = setlist.id
        next.runtime.activeSetlistItemID = firstItem.id
        next.runtime.activeSongID = song.id
        next.runtime.activeSectionID = firstSection.id
        next.runtime.pendingCuePackageID = firstSection.cuePackageID
        next.runtime.transport = .ready
        next.runtime.activeOverrides = []
        next.runtime.lastCommandID = commandID
        next.runtime.revision += 1
        return accepted(next, effects: [.publishState])
    }

    private static func selectSetlistItem(
        state: ShowDirectorReducerState,
        commandID: String,
        itemID: String
    ) -> ShowDirectorReduction {
        guard let graph = state.graph else {
            return rejected(state, "Unknown setlist item.")
        }
        let setlistID = state.runtime.activeSetlistID ?? graph.show.defaultSetlistID
        guard let setlist = graph.setlistsByID[setlistID],
              let item = setlist.items.first(where: { $0.id == itemID }),
              let song = graph.songsByID[item.songScoreID],
              let section = song.sections.first
        else {
            return rejected(state, "Unknown setlist item.")
        }
        var next = pushingUndo(state)
        next.runtime.activeSetlistID = setlist.id
        next.runtime.activeSetlistItemID = item.id
        next.runtime.activeSongID = song.id
        next.runtime.activeSectionID = section.id
        next.runtime.pendingCuePackageID = section.cuePackageID
        next.runtime.transport = .ready
        next.runtime.lastCommandID = commandID
        next.runtime.revision += 1
        return accepted(next, effects: [.publishState])
    }

    private static func go(state: ShowDirectorReducerState, commandID: String) -> ShowDirectorReduction {
        guard state.graph != nil else { return rejected(state, "No show loaded.") }
        if state.runtime.transport == .held {
            return ShowDirectorReduction(
                state: state,
                disposition: .noOp(reason: "Transport is held; GO does not execute.")
            )
        }
        if state.runtime.transport == .parked || state.runtime.transport == .unloaded {
            return rejected(state, "Transport cannot GO from \(state.runtime.transport.rawValue).")
        }

        var next = pushingUndo(state)
        next.runtime.lastCommandID = commandID

        if let queued = next.queuedOverride, queued.placement == .fireNow || queued.placement == .insertNext || queued.placement == .replaceUpcoming {
            // insertNext/replaceUpcoming apply on GO after the current section has already run at least once,
            // or immediately when transport is ready and replace/insert targets upcoming.
            if next.runtime.transport == .ready {
                // First GO fires current section cue; queued insert/replace waits for subsequent GO unless fireNow.
                if queued.placement == .fireNow {
                    return executePresetOverride(&next, commandID: commandID, override: queued)
                }
            } else if next.runtime.transport == .running {
                if queued.placement == .insertNext || queued.placement == .replaceUpcoming || queued.placement == .fireNow {
                    return executePresetOverride(&next, commandID: commandID, override: queued)
                }
            }
        }

        if next.runtime.transport == .ready {
            guard let cueID = currentCuePackageID(in: next) else {
                return rejected(state, "No current cue package.")
            }
            next.runtime.transport = .running
            next.runtime.revision += 1
            return accepted(next, effects: [
                .executeCuePackage(commandID: commandID, cuePackageID: cueID),
                .publishState,
            ])
        }

        // running: advance to next section if possible, else stay and reject.
        guard advanceToNextSection(&next) else {
            return ShowDirectorReduction(
                state: state,
                disposition: .noOp(reason: "Already at final section.")
            )
        }
        guard let cueID = currentCuePackageID(in: next) else {
            return rejected(state, "No current cue package after advance.")
        }
        next.runtime.revision += 1
        return accepted(next, effects: [
            .executeCuePackage(commandID: commandID, cuePackageID: cueID),
            .publishState,
        ])
    }

    private static func executePresetOverride(
        _ state: inout ShowDirectorReducerState,
        commandID: String,
        override: RuntimeOverride
    ) -> ShowDirectorReduction {
        guard let graph = state.graph,
              let preset = graph.presetsByID[override.presetID]
        else {
            return rejected(state, "Queued preset override is missing.")
        }
        state.queuedOverride = nil
        state.runtime.activeOverrides.removeAll { $0.id == override.id }
        state.runtime.pendingCuePackageID = preset.cuePackageID
        state.runtime.transport = .running
        state.runtime.revision += 1
        return accepted(state, effects: [
            .executeCuePackage(commandID: commandID, cuePackageID: preset.cuePackageID),
            .publishState,
        ])
    }

    private static func previous(state: ShowDirectorReducerState, commandID: String) -> ShowDirectorReduction {
        var next = pushingUndo(state)
        guard moveSection(&next, delta: -1) else {
            return ShowDirectorReduction(state: state, disposition: .noOp(reason: "Already at first section."))
        }
        next.runtime.transport = .ready
        next.runtime.lastCommandID = commandID
        next.runtime.revision += 1
        return accepted(next, effects: [.publishState])
    }

    private static func next(state: ShowDirectorReducerState, commandID: String) -> ShowDirectorReduction {
        var next = pushingUndo(state)
        guard moveSection(&next, delta: 1) else {
            return ShowDirectorReduction(state: state, disposition: .noOp(reason: "Already at final section."))
        }
        next.runtime.transport = .ready
        next.runtime.lastCommandID = commandID
        next.runtime.revision += 1
        return accepted(next, effects: [.publishState])
    }

    private static func hold(state: ShowDirectorReducerState, commandID: String) -> ShowDirectorReduction {
        guard state.runtime.transport == .ready || state.runtime.transport == .running else {
            return ShowDirectorReduction(
                state: state,
                disposition: .noOp(reason: "Hold ignored in \(state.runtime.transport.rawValue).")
            )
        }
        var next = pushingUndo(state)
        next.runtime.transport = .held
        next.runtime.lastCommandID = commandID
        next.runtime.revision += 1
        return accepted(next, effects: [.publishState])
    }

    private static func resume(state: ShowDirectorReducerState, commandID: String) -> ShowDirectorReduction {
        guard state.runtime.transport == .held else {
            return ShowDirectorReduction(
                state: state,
                disposition: .noOp(reason: "Resume ignored when not held.")
            )
        }
        var next = pushingUndo(state)
        next.runtime.transport = .running
        next.runtime.lastCommandID = commandID
        next.runtime.revision += 1
        return accepted(next, effects: [.publishState])
    }

    private static func repeatSection(state: ShowDirectorReducerState, commandID: String) -> ShowDirectorReduction {
        guard state.runtime.transport != .held,
              state.runtime.transport != .parked,
              state.runtime.transport != .unloaded,
              let cueID = currentCuePackageID(in: state)
        else {
            return rejected(state, "Cannot repeat section in current transport state.")
        }
        var next = pushingUndo(state)
        next.runtime.transport = .running
        next.runtime.lastCommandID = commandID
        next.runtime.revision += 1
        return accepted(next, effects: [
            .executeCuePackage(commandID: commandID, cuePackageID: cueID),
            .publishState,
        ])
    }

    private static func jumpToSection(
        state: ShowDirectorReducerState,
        commandID: String,
        sectionID: String
    ) -> ShowDirectorReduction {
        guard let graph = state.graph,
              let songID = state.runtime.activeSongID,
              let song = graph.songsByID[songID],
              let section = song.sections.first(where: { $0.id == sectionID })
        else {
            return rejected(state, "Unknown section.")
        }
        var next = pushingUndo(state)
        next.runtime.activeSectionID = section.id
        next.runtime.pendingCuePackageID = section.cuePackageID
        next.runtime.transport = .ready
        next.runtime.lastCommandID = commandID
        next.runtime.revision += 1
        return accepted(next, effects: [.publishState])
    }

    private static func firePresetNow(
        state: ShowDirectorReducerState,
        commandID: String,
        presetID: String
    ) -> ShowDirectorReduction {
        guard let graph = state.graph, let preset = graph.presetsByID[presetID] else {
            return rejected(state, "Unknown preset.")
        }
        var next = pushingUndo(state)
        let override = RuntimeOverride(
            id: "override_\(commandID)",
            presetID: presetID,
            placement: .fireNow,
            createdByCommandID: commandID
        )
        next.runtime.activeOverrides.append(override)
        next.runtime.pendingCuePackageID = preset.cuePackageID
        next.runtime.transport = .running
        next.runtime.lastCommandID = commandID
        next.runtime.revision += 1
        return accepted(next, effects: [
            .executeCuePackage(commandID: commandID, cuePackageID: preset.cuePackageID),
            .publishState,
        ])
    }

    private static func queueOverride(
        state: ShowDirectorReducerState,
        commandID: String,
        presetID: String,
        placement: RuntimeOverridePlacement
    ) -> ShowDirectorReduction {
        guard let graph = state.graph, graph.presetsByID[presetID] != nil else {
            return rejected(state, "Unknown preset.")
        }
        var next = pushingUndo(state)
        let override = RuntimeOverride(
            id: "override_\(commandID)",
            presetID: presetID,
            placement: placement,
            createdByCommandID: commandID
        )
        next.queuedOverride = override
        next.runtime.activeOverrides = [override]
        next.runtime.lastCommandID = commandID
        next.runtime.revision += 1
        return accepted(next, effects: [.publishState])
    }

    private static func undo(state: ShowDirectorReducerState, commandID: String) -> ShowDirectorReduction {
        guard let previous = state.undoSnapshots.last else {
            return ShowDirectorReduction(state: state, disposition: .noOp(reason: "Nothing to undo."))
        }
        var next = state
        next.undoSnapshots.removeLast()
        next.runtime = previous
        next.runtime.lastCommandID = commandID
        next.runtime.revision = state.runtime.revision + 1
        return accepted(next, effects: [.publishState])
    }

    private static func park(state: ShowDirectorReducerState, commandID: String) -> ShowDirectorReduction {
        guard state.graph != nil else { return rejected(state, "No show loaded.") }
        var next = pushingUndo(state)
        next.runtime.transport = .parked
        next.runtime.lastCommandID = commandID
        next.runtime.revision += 1
        return accepted(next, effects: [.publishState])
    }

    private static func safety(
        state: ShowDirectorReducerState,
        commandID: String,
        action: EndpointAction
    ) -> ShowDirectorReduction {
        guard state.graph != nil else { return rejected(state, "No show loaded.") }
        var next = pushingUndo(state)
        next.runtime.lastCommandID = commandID
        next.runtime.revision += 1
        return accepted(next, effects: [
            .executeSafetyAction(commandID: commandID, action: action),
            .publishState,
        ])
    }

    private static func endpointHealthChanged(
        state: ShowDirectorReducerState,
        commandID: String,
        health: EndpointHealth
    ) -> ShowDirectorReduction {
        var next = state
        next.runtime.endpointHealth.removeAll { $0.endpoint == health.endpoint }
        next.runtime.endpointHealth.append(health)
        next.runtime.endpointHealth.sort { $0.endpoint.rawValue < $1.endpoint.rawValue }
        next.runtime.lastCommandID = commandID
        next.runtime.revision += 1
        return accepted(next, effects: [.publishState])
    }

    private static func cueExecutionFinished(
        state: ShowDirectorReducerState,
        commandID: String,
        cuePackageID: String?,
        results: [EndpointActionResult]
    ) -> ShowDirectorReduction {
        _ = results
        var next = state
        next.runtime.lastCommandID = commandID
        if let cuePackageID {
            next.runtime.pendingCuePackageID = cuePackageID
        }
        next.runtime.revision += 1
        return accepted(next, effects: [.publishState])
    }

    // MARK: - Helpers

    private static func accepted(
        _ state: ShowDirectorReducerState,
        effects: [ShowDirectorEffect]
    ) -> ShowDirectorReduction {
        ShowDirectorReduction(state: state, effects: effects, disposition: .accepted)
    }

    private static func rejected(_ state: ShowDirectorReducerState, _ reason: String) -> ShowDirectorReduction {
        ShowDirectorReduction(state: state, disposition: .rejected(reason: reason))
    }

    private static func pushingUndo(_ state: ShowDirectorReducerState) -> ShowDirectorReducerState {
        var next = state
        next.undoSnapshots.append(state.runtime)
        if next.undoSnapshots.count > ShowDirectorReducerState.maxUndoSnapshots {
            next.undoSnapshots.removeFirst(next.undoSnapshots.count - ShowDirectorReducerState.maxUndoSnapshots)
        }
        return next
    }

    private static func currentCuePackageID(in state: ShowDirectorReducerState) -> String? {
        if let pending = state.runtime.pendingCuePackageID { return pending }
        guard let graph = state.graph,
              let songID = state.runtime.activeSongID,
              let sectionID = state.runtime.activeSectionID,
              let song = graph.songsByID[songID],
              let section = song.sections.first(where: { $0.id == sectionID })
        else {
            return nil
        }
        return section.cuePackageID
    }

    private static func advanceToNextSection(_ state: inout ShowDirectorReducerState) -> Bool {
        moveSection(&state, delta: 1)
    }

    @discardableResult
    private static func moveSection(_ state: inout ShowDirectorReducerState, delta: Int) -> Bool {
        guard let graph = state.graph,
              let songID = state.runtime.activeSongID,
              let sectionID = state.runtime.activeSectionID,
              let song = graph.songsByID[songID],
              let index = song.sections.firstIndex(where: { $0.id == sectionID })
        else {
            return false
        }
        let nextIndex = index + delta
        guard song.sections.indices.contains(nextIndex) else { return false }
        let section = song.sections[nextIndex]
        state.runtime.activeSectionID = section.id
        state.runtime.pendingCuePackageID = section.cuePackageID
        return true
    }
}
