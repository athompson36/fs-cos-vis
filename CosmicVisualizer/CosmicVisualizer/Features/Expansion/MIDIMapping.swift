import Foundation

/// Maps MIDI CC to remote command types (JSON-serializable for future file override).
struct MIDIMapping: Codable, Equatable, Sendable {
    struct CCMap: Codable, Equatable, Sendable {
        var channel: Int
        var controller: Int
        var commandType: String
    }

    var cc: [CCMap]

    static func `default`() -> MIDIMapping {
        MIDIMapping(cc: [
            CCMap(channel: 0, controller: 20, commandType: "NextScene"),
            CCMap(channel: 0, controller: 21, commandType: "PreviousScene"),
            CCMap(channel: 0, controller: 22, commandType: "RandomScene"),
            CCMap(channel: 0, controller: 23, commandType: "TapTempo"),
        ])
    }

    func command(forChannel channel: Int, controller: Int) -> RemoteControlCommand? {
        guard let hit = cc.first(where: { $0.channel == channel && $0.controller == controller }) else { return nil }
        return RemoteControlCommand(type: hit.commandType)
    }
}
