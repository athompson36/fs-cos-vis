import Foundation

/// User-controlled remote / hardware I/O settings (persisted).
struct RemoteControlSettings: Codable, Equatable {
    var remoteControlEnabled: Bool = false
    var remoteControlPort: Int = 8765
    /// When false, HTTP server binds to loopback only.
    var bindLAN: Bool = false
    var authToken: String = ""
    var midiInputUID: String = ""
    var dmxSerialDevicePath: String = ""
    var dmxOutputEnabled: Bool = false
}

enum RemoteControlSettingsStore {
    private static let key = "CosmicVisualizer.RemoteControlSettings.v1"

    static func load() -> RemoteControlSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(RemoteControlSettings.self, from: data)
        else {
            return RemoteControlSettings()
        }
        return s
    }

    static func save(_ settings: RemoteControlSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
