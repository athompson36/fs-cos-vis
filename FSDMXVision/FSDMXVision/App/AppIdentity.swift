import Foundation

/// Stable identifiers for on-disk layout and UserDefaults (not marketing copy).
enum AppIdentity {
    /// Subdirectory under `~/Library/Application Support/`.
    static let applicationSupportFolderName = "FSDMXVision"

    /// Previous app name folder; used only when migrating from older installs.
    static let legacyApplicationSupportFolderName = "CosmicVisualizer"

    /// Human-readable product name (Dock, Syphon, UI copy).
    static let displayName = "FS DMX Vision"

    /// Bundle ID of the previous macOS app; used to migrate `~/Library/Preferences/*.plist`.
    static let legacyBundleIdentifier = "com.cosmicvisualizer.app"

    static let remoteControlSettingsDefaultsKey = "FSDMXVision.RemoteControlSettings.v1"
    static let legacyRemoteControlSettingsDefaultsKey = "CosmicVisualizer.RemoteControlSettings.v1"

    static let lastShowProjectFolderDefaultsKey = "FSDMXVision.LastShowProjectFolder.v1"
    static let legacyLastShowProjectFolderDefaultsKey = "CosmicVisualizer.LastShowProjectFolder.v1"

    static func applicationSupportDirectory(fileManager: FileManager = .default) -> URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent(applicationSupportFolderName, isDirectory: true)
    }
}
