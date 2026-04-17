import Foundation

struct ChannelValue: Codable, Equatable, Hashable, Sendable {
    var channel: Int
    var value: UInt8
}

struct LightingCue: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var fadeSeconds: Double
    var channelValues: [ChannelValue]

    init(id: UUID = UUID(), name: String, fadeSeconds: Double = 1, channelValues: [ChannelValue] = []) {
        self.id = id
        self.name = name
        self.fadeSeconds = fadeSeconds
        self.channelValues = channelValues
    }

    var channelMap: [Int: UInt8] {
        Dictionary(uniqueKeysWithValues: channelValues.map { ($0.channel, $0.value) })
    }
}

struct LightingCueDocument: Codable, Equatable, Sendable {
    var version: Int
    var cues: [LightingCue]
    var activeCueIndex: Int?

    static let currentVersion = 1

    init(version: Int = currentVersion, cues: [LightingCue] = [], activeCueIndex: Int? = nil) {
        self.version = version
        self.cues = cues
        self.activeCueIndex = activeCueIndex
    }

    static func `default`() -> LightingCueDocument {
        LightingCueDocument(
            cues: [
                LightingCue(
                    name: "Blackout",
                    fadeSeconds: 0.5,
                    channelValues: (1 ... 12).map { ChannelValue(channel: $0, value: 0) }
                ),
            ],
            activeCueIndex: nil
        )
    }
}
