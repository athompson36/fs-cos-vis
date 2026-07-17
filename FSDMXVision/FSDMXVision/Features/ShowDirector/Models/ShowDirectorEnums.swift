import Foundation

enum ShowDirectorStableID {
    /// Spec: `^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$`, excluding `.` and `..`.
    static let pattern = #"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$"#

    static func isValid(_ id: String) -> Bool {
        guard id != ".", id != ".." else { return false }
        guard id.range(of: pattern, options: .regularExpression) != nil else { return false }
        return true
    }
}

enum SongSectionType: String, Codable, Equatable, Sendable, CaseIterable {
    case intro
    case verse
    case chorus
    case solo
    case breakdown
    case drop
    case outro
    case applause
    case intermission
    case custom
}

enum ShowEndpointKind: String, Codable, Equatable, Sendable, CaseIterable {
    case lighting
    case palette
    case visuals
    case backdropVideo
    case overlay
    case obs
    case camera
    case recording
    case utility
    case midi
    case osc
    case audioRouting
}

enum ShowTransportState: String, Codable, Equatable, Sendable {
    case unloaded
    case ready
    case running
    case held
    case parked
}

enum RuntimeOverridePlacement: String, Codable, Equatable, Sendable {
    case fireNow
    case insertNext
    case replaceUpcoming
}

enum EndpointHealthStatus: String, Codable, Equatable, Sendable {
    case available
    case degraded
    case unavailable
    case unsupported
}

enum EndpointExecutionStatus: String, Codable, Equatable, Sendable {
    case executed
    case skipped
    case unsupported
    case validationFailed
    case timedOut
    case failed
}

enum ShowDirectorDocumentKind: String, Codable, Equatable, Sendable {
    case show
    case setlist
    case song
    case cuePackage
    case preset
}

enum ShowDirectorValidationSeverity: String, Codable, Equatable, Sendable {
    case warning
    case error
}
