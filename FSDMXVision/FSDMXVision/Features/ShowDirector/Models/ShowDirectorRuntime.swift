import Foundation

struct RuntimeOverride: Codable, Equatable, Sendable {
    var id: String
    var presetID: String
    var placement: RuntimeOverridePlacement
    var createdByCommandID: String

    enum CodingKeys: String, CodingKey {
        case id
        case presetID = "presetId"
        case placement
        case createdByCommandID = "createdByCommandId"
    }

    init(
        id: String,
        presetID: String,
        placement: RuntimeOverridePlacement,
        createdByCommandID: String
    ) {
        self.id = id
        self.presetID = presetID
        self.placement = placement
        self.createdByCommandID = createdByCommandID
    }
}

struct EndpointHealth: Codable, Equatable, Sendable {
    var endpoint: ShowEndpointKind
    var status: EndpointHealthStatus
    var message: String?
    var observedAt: Date

    init(
        endpoint: ShowEndpointKind,
        status: EndpointHealthStatus,
        message: String? = nil,
        observedAt: Date
    ) {
        self.endpoint = endpoint
        self.status = status
        self.message = message
        self.observedAt = observedAt
    }
}

struct ShowRuntimeState: Codable, Equatable, Sendable {
    var revision: UInt64
    var showID: String?
    var activeSetlistID: String?
    var activeSetlistItemID: String?
    var activeSongID: String?
    var activeSectionID: String?
    var transport: ShowTransportState
    var pendingCuePackageID: String?
    var activeOverrides: [RuntimeOverride]
    var endpointHealth: [EndpointHealth]
    var lastCommandID: String?

    enum CodingKeys: String, CodingKey {
        case revision
        case showID = "showId"
        case activeSetlistID = "activeSetlistId"
        case activeSetlistItemID = "activeSetlistItemId"
        case activeSongID = "activeSongId"
        case activeSectionID = "activeSectionId"
        case transport
        case pendingCuePackageID = "pendingCuePackageId"
        case activeOverrides
        case endpointHealth
        case lastCommandID = "lastCommandId"
    }

    init(
        revision: UInt64 = 0,
        showID: String? = nil,
        activeSetlistID: String? = nil,
        activeSetlistItemID: String? = nil,
        activeSongID: String? = nil,
        activeSectionID: String? = nil,
        transport: ShowTransportState = .unloaded,
        pendingCuePackageID: String? = nil,
        activeOverrides: [RuntimeOverride] = [],
        endpointHealth: [EndpointHealth] = [],
        lastCommandID: String? = nil
    ) {
        self.revision = revision
        self.showID = showID
        self.activeSetlistID = activeSetlistID
        self.activeSetlistItemID = activeSetlistItemID
        self.activeSongID = activeSongID
        self.activeSectionID = activeSectionID
        self.transport = transport
        self.pendingCuePackageID = pendingCuePackageID
        self.activeOverrides = activeOverrides
        self.endpointHealth = endpointHealth
        self.lastCommandID = lastCommandID
    }

    static let unloaded = ShowRuntimeState()
}

struct ShowDirectorReducerState: Equatable, Sendable {
    static let maxUndoSnapshots = 20

    var runtime: ShowRuntimeState
    var graph: ShowDirectorGraph?
    var queuedOverride: RuntimeOverride?
    var undoSnapshots: [ShowRuntimeState]

    init(
        runtime: ShowRuntimeState = .unloaded,
        graph: ShowDirectorGraph? = nil,
        queuedOverride: RuntimeOverride? = nil,
        undoSnapshots: [ShowRuntimeState] = []
    ) {
        self.runtime = runtime
        self.graph = graph
        self.queuedOverride = queuedOverride
        self.undoSnapshots = undoSnapshots
    }
}

struct EndpointActionResult: Codable, Equatable, Sendable {
    var actionID: String
    var endpoint: ShowEndpointKind
    var status: EndpointExecutionStatus
    var durationMilliseconds: Int
    var message: String?

    enum CodingKeys: String, CodingKey {
        case actionID = "actionId"
        case endpoint
        case status
        case durationMilliseconds = "durationMs"
        case message
    }

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
}

struct ExecutionLogEntry: Codable, Equatable, Sendable {
    var id: String
    var timestamp: Date
    var commandID: String
    var cuePackageID: String?
    var results: [EndpointActionResult]
    var runtimeRevisionBefore: UInt64
    var runtimeRevisionAfter: UInt64

    enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case commandID = "commandId"
        case cuePackageID = "cuePackageId"
        case results
        case runtimeRevisionBefore
        case runtimeRevisionAfter
    }

    init(
        id: String,
        timestamp: Date,
        commandID: String,
        cuePackageID: String? = nil,
        results: [EndpointActionResult],
        runtimeRevisionBefore: UInt64,
        runtimeRevisionAfter: UInt64
    ) {
        self.id = id
        self.timestamp = timestamp
        self.commandID = commandID
        self.cuePackageID = cuePackageID
        self.results = results
        self.runtimeRevisionBefore = runtimeRevisionBefore
        self.runtimeRevisionAfter = runtimeRevisionAfter
    }
}
