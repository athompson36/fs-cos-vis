import Foundation

enum MIDIMappingStore {
    private static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent(AppIdentity.applicationSupportFolderName, isDirectory: true)
            .appendingPathComponent("midi_mapping.json")
    }

    static func loadOrDefault() -> MIDIMapping {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              var decoded = try? JSONDecoder().decode(MIDIMapping.self, from: data)
        else {
            return MIDIMapping.default()
        }
        if decoded.continuousCC.isEmpty {
            decoded.continuousCC = MIDIMapping.defaultContinuousPresets()
        }
        return decoded
    }

    static func save(_ mapping: MIDIMapping) throws {
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(mapping)
        try data.write(to: fileURL, options: .atomic)
    }
}
