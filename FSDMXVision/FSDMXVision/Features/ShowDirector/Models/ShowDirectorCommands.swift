import Foundation

enum ShowDirectorCommand: Equatable, Sendable {
    case loadShow(commandID: String, graph: ShowDirectorGraph)
    case selectSetlistItem(commandID: String, itemID: String)
    case go(commandID: String)
    case previous(commandID: String)
    case next(commandID: String)
    case hold(commandID: String)
    case resume(commandID: String)
    case repeatSection(commandID: String)
    case jumpToSection(commandID: String, sectionID: String)
    case firePresetNow(commandID: String, presetID: String)
    case insertPresetNext(commandID: String, presetID: String)
    case replaceUpcomingCue(commandID: String, presetID: String)
    case undo(commandID: String)
    case park(commandID: String)
    case blackoutLighting(commandID: String)
    case blackoutVideo(commandID: String)
    case restoreSafeLook(commandID: String)
    case endpointHealthChanged(commandID: String, health: EndpointHealth)
    case cueExecutionFinished(commandID: String, cuePackageID: String?, results: [EndpointActionResult])

    var commandID: String {
        switch self {
        case .loadShow(let commandID, _),
             .selectSetlistItem(let commandID, _),
             .go(let commandID),
             .previous(let commandID),
             .next(let commandID),
             .hold(let commandID),
             .resume(let commandID),
             .repeatSection(let commandID),
             .jumpToSection(let commandID, _),
             .firePresetNow(let commandID, _),
             .insertPresetNext(let commandID, _),
             .replaceUpcomingCue(let commandID, _),
             .undo(let commandID),
             .park(let commandID),
             .blackoutLighting(let commandID),
             .blackoutVideo(let commandID),
             .restoreSafeLook(let commandID),
             .endpointHealthChanged(let commandID, _),
             .cueExecutionFinished(let commandID, _, _):
            return commandID
        }
    }
}

enum ShowDirectorEffect: Equatable, Sendable {
    case executeCuePackage(commandID: String, cuePackageID: String)
    case executeSafetyAction(commandID: String, action: EndpointAction)
    case publishState
}

enum ShowDirectorCommandDisposition: Equatable, Sendable {
    case accepted
    case rejected(reason: String)
    case noOp(reason: String)
}

struct ShowDirectorReduction: Equatable, Sendable {
    var state: ShowDirectorReducerState
    var effects: [ShowDirectorEffect]
    var disposition: ShowDirectorCommandDisposition

    init(
        state: ShowDirectorReducerState,
        effects: [ShowDirectorEffect] = [],
        disposition: ShowDirectorCommandDisposition
    ) {
        self.state = state
        self.effects = effects
        self.disposition = disposition
    }
}
