import Foundation

struct ChannelValue: Codable, Equatable, Hashable, Sendable {
    var channel: Int
    var value: UInt8
}

/// Learned fog/haze timing and level from camera luma (per hazer / cue).
struct HazeLearnPreset: Codable, Equatable, Hashable, Sendable {
    /// DMX on `hazeOutput` that matched the learned visual density.
    var steadyHazeDMX: UInt8
    /// Time from baseline luma to steady threshold (seconds).
    var riseTimeSeconds: Double
    /// Rough decay time constant from dissipation sampling (seconds); used for data / future envelope.
    var dissipationHalfLifeSeconds: Double
    var learnedAt: Date?
    var cameraBaselineLuma: Double
    var cameraPeakLuma: Double
    /// Patched hazer instance this preset applies to (required when multiple hazers exist).
    var targetInstanceID: UUID?

    init(
        steadyHazeDMX: UInt8,
        riseTimeSeconds: Double,
        dissipationHalfLifeSeconds: Double,
        learnedAt: Date? = nil,
        cameraBaselineLuma: Double,
        cameraPeakLuma: Double,
        targetInstanceID: UUID? = nil
    ) {
        self.steadyHazeDMX = steadyHazeDMX
        self.riseTimeSeconds = riseTimeSeconds
        self.dissipationHalfLifeSeconds = dissipationHalfLifeSeconds
        self.learnedAt = learnedAt
        self.cameraBaselineLuma = cameraBaselineLuma
        self.cameraPeakLuma = cameraPeakLuma
        self.targetInstanceID = targetInstanceID
    }
}

struct LightingCue: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var fadeSeconds: Double
    var channelValues: [ChannelValue]
    /// Optional PNG path under show media / app support for AI + operator reference.
    var previewThumbnailPath: String?
    /// Camera-assisted learn result; optional.
    var hazeLearnPreset: HazeLearnPreset?
    /// When true and `hazeLearnPreset` is set, runtime shapes hazer output (rise + hold) for this cue.
    var autoApplyHazeEnvelope: Bool

    init(
        id: UUID = UUID(),
        name: String,
        fadeSeconds: Double = 1,
        channelValues: [ChannelValue] = [],
        previewThumbnailPath: String? = nil,
        hazeLearnPreset: HazeLearnPreset? = nil,
        autoApplyHazeEnvelope: Bool = false
    ) {
        self.id = id
        self.name = name
        self.fadeSeconds = fadeSeconds
        self.channelValues = channelValues
        self.previewThumbnailPath = previewThumbnailPath
        self.hazeLearnPreset = hazeLearnPreset
        self.autoApplyHazeEnvelope = autoApplyHazeEnvelope
    }

    var channelMap: [Int: UInt8] {
        Dictionary(uniqueKeysWithValues: channelValues.map { ($0.channel, $0.value) })
    }
}

extension LightingCue {
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case fadeSeconds
        case channelValues
        case previewThumbnailPath
        case hazeLearnPreset
        case autoApplyHazeEnvelope
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        fadeSeconds = try c.decodeIfPresent(Double.self, forKey: .fadeSeconds) ?? 1
        channelValues = try c.decodeIfPresent([ChannelValue].self, forKey: .channelValues) ?? []
        previewThumbnailPath = try c.decodeIfPresent(String.self, forKey: .previewThumbnailPath)
        hazeLearnPreset = try c.decodeIfPresent(HazeLearnPreset.self, forKey: .hazeLearnPreset)
        autoApplyHazeEnvelope = try c.decodeIfPresent(Bool.self, forKey: .autoApplyHazeEnvelope) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(fadeSeconds, forKey: .fadeSeconds)
        try c.encode(channelValues, forKey: .channelValues)
        try c.encodeIfPresent(previewThumbnailPath, forKey: .previewThumbnailPath)
        try c.encodeIfPresent(hazeLearnPreset, forKey: .hazeLearnPreset)
        try c.encode(autoApplyHazeEnvelope, forKey: .autoApplyHazeEnvelope)
    }
}

struct LightingCueDocument: Codable, Equatable, Sendable {
    var version: Int
    var cues: [LightingCue]
    var activeCueIndex: Int?
    /// Bookmarked cues for quick access (Live Show drawer); order is significant.
    var bookmarkedCueIds: [UUID]

    static let currentVersion = 3

    init(version: Int = currentVersion, cues: [LightingCue] = [], activeCueIndex: Int? = nil, bookmarkedCueIds: [UUID] = []) {
        self.version = version
        self.cues = cues
        self.activeCueIndex = activeCueIndex
        self.bookmarkedCueIds = bookmarkedCueIds
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
            activeCueIndex: nil,
            bookmarkedCueIds: []
        )
    }
}

extension LightingCueDocument {
    enum CodingKeys: String, CodingKey {
        case version
        case cues
        case activeCueIndex
        case bookmarkedCueIds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        cues = try c.decodeIfPresent([LightingCue].self, forKey: .cues) ?? []
        activeCueIndex = try c.decodeIfPresent(Int.self, forKey: .activeCueIndex)
        bookmarkedCueIds = try c.decodeIfPresent([UUID].self, forKey: .bookmarkedCueIds) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(version, forKey: .version)
        try c.encode(cues, forKey: .cues)
        try c.encodeIfPresent(activeCueIndex, forKey: .activeCueIndex)
        try c.encode(bookmarkedCueIds, forKey: .bookmarkedCueIds)
    }
}
