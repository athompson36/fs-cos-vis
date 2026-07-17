import Foundation

enum ShowDirectorPackageStoreError: Error, LocalizedError, Equatable {
    case documentIDMismatch(expected: String, actual: String, path: String)
    case validationFailed([ShowDirectorValidationIssue])
    case replacementFailed(String)
    case missingShowIndex

    var errorDescription: String? {
        switch self {
        case .documentIDMismatch(let expected, let actual, let path):
            return "Document ID mismatch at \(path): expected \(expected), found \(actual)."
        case .validationFailed(let issues):
            return issues.map { "\($0.path): \($0.message)" }.joined(separator: "\n")
        case .replacementFailed(let message):
            return "Show Director package replacement failed: \(message)"
        case .missingShowIndex:
            return "show-director/show.json is missing."
        }
    }
}

struct ShowDirectorPackageLoadResult: Equatable, Sendable {
    var graph: ShowDirectorGraph?
    var validation: ShowDirectorValidationResult
}

enum ShowDirectorPackageLayout {
    static let rootDirectoryName = "show-director"
    static let showFilename = "show.json"
    static let setlistsDirectoryName = "setlists"
    static let songsDirectoryName = "songs"
    static let cuePackagesDirectoryName = "cue-packages"
    static let presetsDirectoryName = "presets"
    static let logsDirectoryName = "logs"
    static let executionLogFilename = "execution.jsonl"
    static let mediaDirectoryName = "Media"
    static let mediaVideoDirectoryName = "video"
    static let mediaImagesDirectoryName = "images"
    static let mediaOverlaysDirectoryName = "overlays"

    static func showDirectorDirectory(in packageRoot: URL) -> URL {
        packageRoot.appendingPathComponent(rootDirectoryName, isDirectory: true)
    }

    static func mediaDirectory(in packageRoot: URL) -> URL {
        packageRoot.appendingPathComponent(mediaDirectoryName, isDirectory: true)
    }

    static func executionLogURL(in packageRoot: URL) -> URL {
        showDirectorDirectory(in: packageRoot)
            .appendingPathComponent(logsDirectoryName, isDirectory: true)
            .appendingPathComponent(executionLogFilename)
    }
}

enum ShowDirectorPackageStore {
    /// Loads an optional Show Director graph. Missing `show-director/` returns `graph == nil`.
    static func load(
        from packageRoot: URL,
        registeredAdapters: Set<ShowEndpointKind> = [],
        allowValidationErrors: Bool = false
    ) throws -> ShowDirectorPackageLoadResult {
        let root = ShowDirectorPackageLayout.showDirectorDirectory(in: packageRoot)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDir), isDir.boolValue else {
            return ShowDirectorPackageLoadResult(
                graph: nil,
                validation: ShowDirectorValidationResult(issues: [])
            )
        }

        let showURL = root.appendingPathComponent(ShowDirectorPackageLayout.showFilename)
        guard FileManager.default.fileExists(atPath: showURL.path) else {
            throw ShowDirectorPackageStoreError.missingShowIndex
        }

        let showData = try ShowDirectorMigrator.migrateDocumentData(
            try Data(contentsOf: showURL),
            kind: .show
        )
        let show = try ShowDirectorJSON.makeDecoder().decode(ShowDocument.self, from: showData)

        let setlists = try loadCollection(
            directory: root.appendingPathComponent(ShowDirectorPackageLayout.setlistsDirectoryName, isDirectory: true),
            kind: .setlist,
            decode: { try ShowDirectorJSON.makeDecoder().decode(Setlist.self, from: $0) },
            documentID: \.id
        )
        let songs = try loadCollection(
            directory: root.appendingPathComponent(ShowDirectorPackageLayout.songsDirectoryName, isDirectory: true),
            kind: .song,
            decode: { try ShowDirectorJSON.makeDecoder().decode(SongScore.self, from: $0) },
            documentID: \.id
        )
        let cues = try loadCollection(
            directory: root.appendingPathComponent(ShowDirectorPackageLayout.cuePackagesDirectoryName, isDirectory: true),
            kind: .cuePackage,
            decode: { try ShowDirectorJSON.makeDecoder().decode(CuePackage.self, from: $0) },
            documentID: \.id
        )
        let presets = try loadCollection(
            directory: root.appendingPathComponent(ShowDirectorPackageLayout.presetsDirectoryName, isDirectory: true),
            kind: .preset,
            decode: { try ShowDirectorJSON.makeDecoder().decode(ShowPreset.self, from: $0) },
            documentID: \.id
        )

        let graph = ShowDirectorGraph(
            show: show,
            setlistsByID: setlists,
            songsByID: songs,
            cuePackagesByID: cues,
            presetsByID: presets
        )
        let validation = ShowDirectorValidator.validate(
            graph,
            packageRoot: packageRoot,
            registeredAdapters: registeredAdapters
        )
        if validation.hasErrors, !allowValidationErrors {
            throw ShowDirectorPackageStoreError.validationFailed(validation.errors)
        }
        return ShowDirectorPackageLoadResult(graph: graph, validation: validation)
    }

    static func save(
        _ graph: ShowDirectorGraph,
        to packageRoot: URL,
        registeredAdapters: Set<ShowEndpointKind> = [],
        fileManager: FileManager = .default
    ) throws {
        try ensureMediaLayout(in: packageRoot, fileManager: fileManager)

        let validation = ShowDirectorValidator.validate(
            graph,
            packageRoot: packageRoot,
            registeredAdapters: registeredAdapters
        )
        if validation.hasErrors {
            throw ShowDirectorPackageStoreError.validationFailed(validation.errors)
        }

        let destination = ShowDirectorPackageLayout.showDirectorDirectory(in: packageRoot)
        let tempPackage = packageRoot.appendingPathComponent(
            ".show-director-temp-package-\(UUID().uuidString)",
            isDirectory: true
        )
        let backup = packageRoot.appendingPathComponent(
            ".show-director-backup-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? fileManager.removeItem(at: tempPackage) }

        try fileManager.createDirectory(at: tempPackage, withIntermediateDirectories: true)
        let mediaSource = ShowDirectorPackageLayout.mediaDirectory(in: packageRoot)
        if fileManager.fileExists(atPath: mediaSource.path) {
            try? fileManager.createSymbolicLink(
                at: ShowDirectorPackageLayout.mediaDirectory(in: tempPackage),
                withDestinationURL: mediaSource
            )
        }

        let stagedShowDirector = ShowDirectorPackageLayout.showDirectorDirectory(in: tempPackage)
        try writeGraph(graph, to: stagedShowDirector, fileManager: fileManager)
        // Confirm staged content reloads cleanly before replacing the live tree.
        _ = try load(from: tempPackage, registeredAdapters: registeredAdapters)

        // Preserve existing logs if present.
        let existingLogs = destination
            .appendingPathComponent(ShowDirectorPackageLayout.logsDirectoryName, isDirectory: true)
            .appendingPathComponent(ShowDirectorPackageLayout.executionLogFilename)
        let stagedLogsDir = stagedShowDirector.appendingPathComponent(
            ShowDirectorPackageLayout.logsDirectoryName,
            isDirectory: true
        )
        if fileManager.fileExists(atPath: existingLogs.path) {
            try fileManager.createDirectory(at: stagedLogsDir, withIntermediateDirectories: true)
            try fileManager.copyItem(
                at: existingLogs,
                to: stagedLogsDir.appendingPathComponent(ShowDirectorPackageLayout.executionLogFilename)
            )
        }

        let hadExisting = fileManager.fileExists(atPath: destination.path)
        do {
            if hadExisting {
                try fileManager.moveItem(at: destination, to: backup)
            }
            try fileManager.moveItem(at: stagedShowDirector, to: destination)
            if hadExisting {
                try? fileManager.removeItem(at: backup)
            }
        } catch {
            if hadExisting, fileManager.fileExists(atPath: backup.path) {
                try? fileManager.removeItem(at: destination)
                try? fileManager.moveItem(at: backup, to: destination)
            }
            throw ShowDirectorPackageStoreError.replacementFailed(error.localizedDescription)
        }
    }

    static func ensureMediaLayout(in packageRoot: URL, fileManager: FileManager = .default) throws {
        let media = ShowDirectorPackageLayout.mediaDirectory(in: packageRoot)
        try fileManager.createDirectory(at: media, withIntermediateDirectories: true)
        for name in [
            ShowDirectorPackageLayout.mediaVideoDirectoryName,
            ShowDirectorPackageLayout.mediaImagesDirectoryName,
            ShowDirectorPackageLayout.mediaOverlaysDirectoryName,
        ] {
            try fileManager.createDirectory(
                at: media.appendingPathComponent(name, isDirectory: true),
                withIntermediateDirectories: true
            )
        }
    }

    private static func writeGraph(
        _ graph: ShowDirectorGraph,
        to root: URL,
        fileManager: FileManager
    ) throws {
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: root.appendingPathComponent(ShowDirectorPackageLayout.logsDirectoryName, isDirectory: true),
            withIntermediateDirectories: true
        )

        let encoder = ShowDirectorJSON.makeEncoder()
        try encoder.encode(graph.show).write(
            to: root.appendingPathComponent(ShowDirectorPackageLayout.showFilename),
            options: .atomic
        )

        try writeDocuments(
            graph.show.setlistIDs.sorted().compactMap { graph.setlistsByID[$0] },
            directoryName: ShowDirectorPackageLayout.setlistsDirectoryName,
            root: root,
            fileManager: fileManager,
            encode: { try encoder.encode($0) },
            id: \.id
        )
        try writeDocuments(
            graph.show.songIDs.sorted().compactMap { graph.songsByID[$0] },
            directoryName: ShowDirectorPackageLayout.songsDirectoryName,
            root: root,
            fileManager: fileManager,
            encode: { try encoder.encode($0) },
            id: \.id
        )
        try writeDocuments(
            graph.show.cuePackageIDs.sorted().compactMap { graph.cuePackagesByID[$0] },
            directoryName: ShowDirectorPackageLayout.cuePackagesDirectoryName,
            root: root,
            fileManager: fileManager,
            encode: { try encoder.encode($0) },
            id: \.id
        )
        try writeDocuments(
            graph.show.presetIDs.sorted().compactMap { graph.presetsByID[$0] },
            directoryName: ShowDirectorPackageLayout.presetsDirectoryName,
            root: root,
            fileManager: fileManager,
            encode: { try encoder.encode($0) },
            id: \.id
        )
    }

    private static func writeDocuments<T>(
        _ documents: [T],
        directoryName: String,
        root: URL,
        fileManager: FileManager,
        encode: (T) throws -> Data,
        id: KeyPath<T, String>
    ) throws {
        let directory = root.appendingPathComponent(directoryName, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        for document in documents {
            let documentID = document[keyPath: id]
            let url = directory.appendingPathComponent("\(documentID).json")
            try encode(document).write(to: url, options: .atomic)
        }
    }

    private static func loadCollection<T>(
        directory: URL,
        kind: ShowDirectorDocumentKind,
        decode: (Data) throws -> T,
        documentID: KeyPath<T, String>
    ) throws -> [String: T] {
        var result: [String: T] = [:]
        let fm = FileManager.default
        guard fm.fileExists(atPath: directory.path) else { return result }
        let files = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        for file in files {
            let expectedID = file.deletingPathExtension().lastPathComponent
            let migrated = try ShowDirectorMigrator.migrateDocumentData(try Data(contentsOf: file), kind: kind)
            let decoded = try decode(migrated)
            let actualID = decoded[keyPath: documentID]
            if actualID != expectedID {
                throw ShowDirectorPackageStoreError.documentIDMismatch(
                    expected: expectedID,
                    actual: actualID,
                    path: file.lastPathComponent
                )
            }
            result[actualID] = decoded
        }
        return result
    }
}
