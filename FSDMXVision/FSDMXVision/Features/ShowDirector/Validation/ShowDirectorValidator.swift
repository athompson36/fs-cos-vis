import Foundation

struct ShowDirectorValidationIssue: Codable, Equatable, Sendable {
    var severity: ShowDirectorValidationSeverity
    var code: String
    var path: String
    var message: String

    init(
        severity: ShowDirectorValidationSeverity,
        code: String,
        path: String,
        message: String
    ) {
        self.severity = severity
        self.code = code
        self.path = path
        self.message = message
    }
}

struct ShowDirectorValidationResult: Equatable, Sendable {
    var issues: [ShowDirectorValidationIssue]

    var errors: [ShowDirectorValidationIssue] {
        issues.filter { $0.severity == .error }
    }

    var warnings: [ShowDirectorValidationIssue] {
        issues.filter { $0.severity == .warning }
    }

    var hasErrors: Bool { !errors.isEmpty }
}

enum ShowDirectorValidator {
    /// Validates a fully assembled graph. Optional `packageRoot` enables missing-media warnings.
    /// Optional `registeredAdapters` enables missing-adapter warnings.
    static func validate(
        _ graph: ShowDirectorGraph,
        packageRoot: URL? = nil,
        registeredAdapters: Set<ShowEndpointKind> = []
    ) -> ShowDirectorValidationResult {
        var issues: [ShowDirectorValidationIssue] = []

        validateSchemaVersions(graph, into: &issues)
        validateID(graph.show.id, path: "show.id", into: &issues)
        for (index, id) in graph.show.setlistIDs.enumerated() {
            validateID(id, path: "show.setlistIds[\(index)]", into: &issues)
        }
        for (index, id) in graph.show.songIDs.enumerated() {
            validateID(id, path: "show.songIds[\(index)]", into: &issues)
        }
        for (index, id) in graph.show.cuePackageIDs.enumerated() {
            validateID(id, path: "show.cuePackageIds[\(index)]", into: &issues)
        }
        for (index, id) in graph.show.presetIDs.enumerated() {
            validateID(id, path: "show.presetIds[\(index)]", into: &issues)
        }

        if !graph.show.setlistIDs.contains(graph.show.defaultSetlistID) {
            issues.append(.init(
                severity: .error,
                code: "default_setlist_missing",
                path: "show.defaultSetlistId",
                message: "defaultSetlistId \"\(graph.show.defaultSetlistID)\" is not listed in setlistIds."
            ))
        }

        reportDuplicates(graph.show.setlistIDs, pathPrefix: "show.setlistIds", code: "duplicate_setlist_id", into: &issues)
        reportDuplicates(graph.show.songIDs, pathPrefix: "show.songIds", code: "duplicate_song_id", into: &issues)
        reportDuplicates(graph.show.cuePackageIDs, pathPrefix: "show.cuePackageIds", code: "duplicate_cue_package_id", into: &issues)
        reportDuplicates(graph.show.presetIDs, pathPrefix: "show.presetIds", code: "duplicate_preset_id", into: &issues)

        for id in graph.show.setlistIDs where graph.setlistsByID[id] == nil {
            issues.append(.init(
                severity: .error,
                code: "missing_setlist_document",
                path: "setlists/\(id).json",
                message: "Indexed setlist \"\(id)\" has no document."
            ))
        }
        for id in graph.setlistsByID.keys where !graph.show.setlistIDs.contains(id) {
            issues.append(.init(
                severity: .error,
                code: "unindexed_setlist_document",
                path: "setlists/\(id).json",
                message: "Setlist document \"\(id)\" is not indexed by show.setlistIds."
            ))
        }
        for id in graph.show.songIDs where graph.songsByID[id] == nil {
            issues.append(.init(
                severity: .error,
                code: "missing_song_document",
                path: "songs/\(id).json",
                message: "Indexed song \"\(id)\" has no document."
            ))
        }
        for id in graph.songsByID.keys where !graph.show.songIDs.contains(id) {
            issues.append(.init(
                severity: .error,
                code: "unindexed_song_document",
                path: "songs/\(id).json",
                message: "Song document \"\(id)\" is not indexed by show.songIds."
            ))
        }
        for id in graph.show.cuePackageIDs where graph.cuePackagesByID[id] == nil {
            issues.append(.init(
                severity: .error,
                code: "missing_cue_package_document",
                path: "cue-packages/\(id).json",
                message: "Indexed cue package \"\(id)\" has no document."
            ))
        }
        for id in graph.cuePackagesByID.keys where !graph.show.cuePackageIDs.contains(id) {
            issues.append(.init(
                severity: .error,
                code: "unindexed_cue_package_document",
                path: "cue-packages/\(id).json",
                message: "Cue package document \"\(id)\" is not indexed by show.cuePackageIds."
            ))
        }
        for id in graph.show.presetIDs where graph.presetsByID[id] == nil {
            issues.append(.init(
                severity: .error,
                code: "missing_preset_document",
                path: "presets/\(id).json",
                message: "Indexed preset \"\(id)\" has no document."
            ))
        }
        for id in graph.presetsByID.keys where !graph.show.presetIDs.contains(id) {
            issues.append(.init(
                severity: .error,
                code: "unindexed_preset_document",
                path: "presets/\(id).json",
                message: "Preset document \"\(id)\" is not indexed by show.presetIds."
            ))
        }

        for setlistID in graph.show.setlistIDs.sorted() {
            guard let setlist = graph.setlistsByID[setlistID] else { continue }
            if setlist.id != setlistID {
                issues.append(.init(
                    severity: .error,
                    code: "document_id_mismatch",
                    path: "setlists/\(setlistID).json",
                    message: "Filename ID \"\(setlistID)\" does not match document id \"\(setlist.id)\"."
                ))
            }
            let itemIDs = setlist.items.map(\.id)
            reportDuplicates(itemIDs, pathPrefix: "setlists/\(setlistID).items", code: "duplicate_setlist_item_id", into: &issues)
            for (index, item) in setlist.items.enumerated() {
                validateID(item.id, path: "setlists/\(setlistID).items[\(index)].id", into: &issues)
                if graph.songsByID[item.songScoreID] == nil {
                    issues.append(.init(
                        severity: .error,
                        code: "missing_song_reference",
                        path: "setlists/\(setlistID).items[\(index)].songScoreId",
                        message: "Setlist item references missing song \"\(item.songScoreID)\"."
                    ))
                }
            }
        }

        for songID in graph.show.songIDs.sorted() {
            guard let song = graph.songsByID[songID] else { continue }
            if song.id != songID {
                issues.append(.init(
                    severity: .error,
                    code: "document_id_mismatch",
                    path: "songs/\(songID).json",
                    message: "Filename ID \"\(songID)\" does not match document id \"\(song.id)\"."
                ))
            }
            if song.bpm == nil {
                issues.append(.init(
                    severity: .warning,
                    code: "missing_bpm",
                    path: "songs/\(songID).bpm",
                    message: "Optional BPM is absent."
                ))
            }
            if song.musicalKey == nil {
                issues.append(.init(
                    severity: .warning,
                    code: "missing_musical_key",
                    path: "songs/\(songID).key",
                    message: "Optional musical key is absent."
                ))
            }
            reportDuplicates(
                song.sections.map(\.id),
                pathPrefix: "songs/\(songID).sections",
                code: "duplicate_section_id",
                into: &issues
            )
            for (index, section) in song.sections.enumerated() {
                validateID(section.id, path: "songs/\(songID).sections[\(index)].id", into: &issues)
                if graph.cuePackagesByID[section.cuePackageID] == nil {
                    issues.append(.init(
                        severity: .error,
                        code: "missing_cue_package_reference",
                        path: "songs/\(songID).sections[\(index)].cuePackageId",
                        message: "Section references missing cue package \"\(section.cuePackageID)\"."
                    ))
                }
            }
        }

        for cueID in graph.show.cuePackageIDs.sorted() {
            guard let cue = graph.cuePackagesByID[cueID] else { continue }
            if cue.id != cueID {
                issues.append(.init(
                    severity: .error,
                    code: "document_id_mismatch",
                    path: "cue-packages/\(cueID).json",
                    message: "Filename ID \"\(cueID)\" does not match document id \"\(cue.id)\"."
                ))
            }
            reportDuplicates(
                cue.actions.map(\.id),
                pathPrefix: "cue-packages/\(cueID).actions",
                code: "duplicate_action_id",
                into: &issues
            )
            for action in cue.actions {
                if !registeredAdapters.isEmpty, !registeredAdapters.contains(action.endpointKind) {
                    issues.append(.init(
                        severity: .warning,
                        code: "missing_adapter",
                        path: "cue-packages/\(cueID).actions[\(action.id)]",
                        message: "No registered adapter for endpoint \"\(action.endpointKind.rawValue)\"."
                    ))
                }
                if case .playBackdropClip(_, let clipID, _, _) = action {
                    validateMediaReference(
                        "Media/video/\(clipID).mp4",
                        path: "cue-packages/\(cueID).actions[\(action.id)].clipId",
                        packageRoot: packageRoot,
                        into: &issues
                    )
                }
            }
        }

        for presetID in graph.show.presetIDs.sorted() {
            guard let preset = graph.presetsByID[presetID] else { continue }
            if preset.id != presetID {
                issues.append(.init(
                    severity: .error,
                    code: "document_id_mismatch",
                    path: "presets/\(presetID).json",
                    message: "Filename ID \"\(presetID)\" does not match document id \"\(preset.id)\"."
                ))
            }
            if graph.cuePackagesByID[preset.cuePackageID] == nil {
                issues.append(.init(
                    severity: .error,
                    code: "missing_cue_package_reference",
                    path: "presets/\(presetID).cuePackageId",
                    message: "Preset references missing cue package \"\(preset.cuePackageID)\"."
                ))
            }
        }

        issues.sort {
            if $0.path != $1.path { return $0.path < $1.path }
            if $0.code != $1.code { return $0.code < $1.code }
            return $0.message < $1.message
        }
        return ShowDirectorValidationResult(issues: issues)
    }

    private static func validateSchemaVersions(
        _ graph: ShowDirectorGraph,
        into issues: inout [ShowDirectorValidationIssue]
    ) {
        func check(_ version: Int, path: String, current: Int) {
            if version > current {
                issues.append(.init(
                    severity: .error,
                    code: "unsupported_future_schema_version",
                    path: path,
                    message: "schemaVersion \(version) is newer than supported \(current)."
                ))
            } else if version < 1 {
                issues.append(.init(
                    severity: .error,
                    code: "unsupported_schema_version",
                    path: path,
                    message: "schemaVersion \(version) is unsupported."
                ))
            }
        }
        check(graph.show.schemaVersion, path: "show.schemaVersion", current: ShowDocument.currentSchemaVersion)
        for (id, setlist) in graph.setlistsByID {
            check(setlist.schemaVersion, path: "setlists/\(id).schemaVersion", current: Setlist.currentSchemaVersion)
        }
        for (id, song) in graph.songsByID {
            check(song.schemaVersion, path: "songs/\(id).schemaVersion", current: SongScore.currentSchemaVersion)
        }
        for (id, cue) in graph.cuePackagesByID {
            check(cue.schemaVersion, path: "cue-packages/\(id).schemaVersion", current: CuePackage.currentSchemaVersion)
        }
        for (id, preset) in graph.presetsByID {
            check(preset.schemaVersion, path: "presets/\(id).schemaVersion", current: ShowPreset.currentSchemaVersion)
        }
    }

    private static func validateID(
        _ id: String,
        path: String,
        into issues: inout [ShowDirectorValidationIssue]
    ) {
        if id.isEmpty || !ShowDirectorStableID.isValid(id) {
            issues.append(.init(
                severity: .error,
                code: "invalid_stable_id",
                path: path,
                message: "Stable ID \"\(id)\" is invalid."
            ))
        }
    }

    private static func reportDuplicates(
        _ ids: [String],
        pathPrefix: String,
        code: String,
        into issues: inout [ShowDirectorValidationIssue]
    ) {
        var seen: [String: Int] = [:]
        for (index, id) in ids.enumerated() {
            if let first = seen[id] {
                issues.append(.init(
                    severity: .error,
                    code: code,
                    path: "\(pathPrefix)[\(index)]",
                    message: "Duplicate ID \"\(id)\" (first seen at index \(first))."
                ))
            } else {
                seen[id] = index
            }
        }
    }

    private static func validateMediaReference(
        _ relativePath: String,
        path: String,
        packageRoot: URL?,
        into issues: inout [ShowDirectorValidationIssue]
    ) {
        if relativePath.hasPrefix("/") || relativePath.contains("://") {
            issues.append(.init(
                severity: .error,
                code: "absolute_media_path",
                path: path,
                message: "Media path must be package-relative and begin with Media/."
            ))
            return
        }
        if relativePath.contains("..") || !relativePath.hasPrefix("Media/") {
            issues.append(.init(
                severity: .error,
                code: "escaping_media_path",
                path: path,
                message: "Media path \"\(relativePath)\" escapes the package or is not under Media/."
            ))
            return
        }
        guard let packageRoot else { return }
        let url = packageRoot.appendingPathComponent(relativePath)
        if !FileManager.default.fileExists(atPath: url.path) {
            issues.append(.init(
                severity: .warning,
                code: "missing_media",
                path: path,
                message: "Referenced media \"\(relativePath)\" is missing."
            ))
        }
    }
}
