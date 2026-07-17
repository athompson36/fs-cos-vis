import Foundation

enum ShowDirectorMigrationError: Error, LocalizedError, Equatable {
    case unsupportedFutureSchemaVersion(kind: ShowDirectorDocumentKind, version: Int, current: Int)
    case unsupportedSchemaVersion(kind: ShowDirectorDocumentKind, version: Int)
    case missingSchemaVersion(kind: ShowDirectorDocumentKind)

    var errorDescription: String? {
        switch self {
        case .unsupportedFutureSchemaVersion(let kind, let version, let current):
            return "\(kind.rawValue) schemaVersion \(version) is newer than supported \(current)."
        case .unsupportedSchemaVersion(let kind, let version):
            return "\(kind.rawValue) schemaVersion \(version) is unsupported."
        case .missingSchemaVersion(let kind):
            return "\(kind.rawValue) is missing schemaVersion."
        }
    }
}

enum ShowDirectorMigrator {
    static func migrateDocumentData(
        _ data: Data,
        kind: ShowDirectorDocumentKind
    ) throws -> Data {
        let object = try JSONSerialization.jsonObject(with: data)
        guard var dict = object as? [String: Any] else {
            throw ShowDirectorMigrationError.missingSchemaVersion(kind: kind)
        }
        guard let version = dict["schemaVersion"] as? Int else {
            throw ShowDirectorMigrationError.missingSchemaVersion(kind: kind)
        }
        let current = currentSchemaVersion(for: kind)
        if version > current {
            throw ShowDirectorMigrationError.unsupportedFutureSchemaVersion(
                kind: kind,
                version: version,
                current: current
            )
        }
        if version < 1 {
            throw ShowDirectorMigrationError.unsupportedSchemaVersion(kind: kind, version: version)
        }

        var migratedVersion = version
        while migratedVersion < current {
            // No historical migrations yet; loop reserved for future one-version steps.
            migratedVersion += 1
            dict["schemaVersion"] = migratedVersion
        }
        dict["schemaVersion"] = current
        return try JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys, .prettyPrinted])
    }

    private static func currentSchemaVersion(for kind: ShowDirectorDocumentKind) -> Int {
        switch kind {
        case .show: return ShowDocument.currentSchemaVersion
        case .setlist: return Setlist.currentSchemaVersion
        case .song: return SongScore.currentSchemaVersion
        case .cuePackage: return CuePackage.currentSchemaVersion
        case .preset: return ShowPreset.currentSchemaVersion
        }
    }
}
