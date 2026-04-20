import Foundation

/// One-time migration from legacy installs (`com.cosmicvisualizer.app`) before the **FS DMX Vision** rebrand.
enum LegacyInstallMigration {
    private static let markerFilename = ".migrated_from_cosmicvisualizer_v1"

    static func runIfNeeded() {
        let fm = FileManager.default
        migrateApplicationSupportFolder(fm: fm)
        migrateLegacyPreferencesPlist(fm: fm)
    }

    private static func migrateApplicationSupportFolder(fm: FileManager) {
        guard let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let newDir = base.appendingPathComponent(AppIdentity.applicationSupportFolderName, isDirectory: true)
        let oldDir = base.appendingPathComponent(AppIdentity.legacyApplicationSupportFolderName, isDirectory: true)
        guard !fm.fileExists(atPath: newDir.path), fm.fileExists(atPath: oldDir.path) else { return }
        do {
            try fm.moveItem(at: oldDir, to: newDir)
        } catch {
            // If move fails, leave both; user can merge manually.
        }
    }

    private static func migrateLegacyPreferencesPlist(fm: FileManager) {
        let support = AppIdentity.applicationSupportDirectory(fileManager: fm)
        do {
            try fm.createDirectory(at: support, withIntermediateDirectories: true)
        } catch {
            return
        }
        let marker = support.appendingPathComponent(markerFilename)
        if fm.fileExists(atPath: marker.path) { return }

        let legacyPlist = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/\(AppIdentity.legacyBundleIdentifier).plist")
        guard fm.fileExists(atPath: legacyPlist.path),
              let legacy = NSDictionary(contentsOf: legacyPlist) as? [String: Any]
        else {
            try? Data().write(to: marker, options: .atomic)
            return
        }

        let defaults = UserDefaults.standard
        let prefix = "CosmicVisualizer."
        let newPrefix = "FSDMXVision."

        for (key, value) in legacy {
            var newKey = key
            if key.hasPrefix(prefix) {
                newKey = newPrefix + String(key.dropFirst(prefix.count))
            }

            if newKey == AppIdentity.lastShowProjectFolderDefaultsKey
                || key == AppIdentity.legacyLastShowProjectFolderDefaultsKey,
                let s = value as? String
            {
                let fixed = rewriteLegacyApplicationSupportPaths(s)
                if defaults.object(forKey: newKey) == nil {
                    defaults.set(fixed, forKey: newKey)
                }
                continue
            }

            if defaults.object(forKey: newKey) == nil {
                defaults.set(value, forKey: newKey)
            }
        }
        defaults.synchronize()
        try? Data().write(to: marker, options: .atomic)
    }

    private static func rewriteLegacyApplicationSupportPaths(_ path: String) -> String {
        path
            .replacingOccurrences(
                of: "/Application Support/\(AppIdentity.legacyApplicationSupportFolderName)/",
                with: "/Application Support/\(AppIdentity.applicationSupportFolderName)/"
            )
            .replacingOccurrences(
                of: "/Application Support/\(AppIdentity.legacyApplicationSupportFolderName)",
                with: "/Application Support/\(AppIdentity.applicationSupportFolderName)"
            )
    }
}
