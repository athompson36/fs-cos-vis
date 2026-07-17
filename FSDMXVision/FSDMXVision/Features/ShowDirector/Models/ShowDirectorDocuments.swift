import Foundation

struct ShowDirectorMetadata: Codable, Equatable, Sendable {
    var name: String
    var artist: String?
    var notes: String?

    init(name: String, artist: String? = nil, notes: String? = nil) {
        self.name = name
        self.artist = artist
        self.notes = notes
    }
}

struct ShowDocument: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var id: String
    var metadata: ShowDirectorMetadata
    var defaultSetlistID: String
    var setlistIDs: [String]
    var songIDs: [String]
    var cuePackageIDs: [String]
    var presetIDs: [String]

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id
        case metadata
        case defaultSetlistID = "defaultSetlistId"
        case setlistIDs = "setlistIds"
        case songIDs = "songIds"
        case cuePackageIDs = "cuePackageIds"
        case presetIDs = "presetIds"
    }

    init(
        schemaVersion: Int = currentSchemaVersion,
        id: String,
        metadata: ShowDirectorMetadata,
        defaultSetlistID: String,
        setlistIDs: [String],
        songIDs: [String],
        cuePackageIDs: [String],
        presetIDs: [String]
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.metadata = metadata
        self.defaultSetlistID = defaultSetlistID
        self.setlistIDs = setlistIDs
        self.songIDs = songIDs
        self.cuePackageIDs = cuePackageIDs
        self.presetIDs = presetIDs
    }
}

struct SetlistItem: Codable, Equatable, Sendable {
    var id: String
    var songScoreID: String
    var label: String

    enum CodingKeys: String, CodingKey {
        case id
        case songScoreID = "songScoreId"
        case label
    }

    init(id: String, songScoreID: String, label: String) {
        self.id = id
        self.songScoreID = songScoreID
        self.label = label
    }
}

struct Setlist: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var id: String
    var name: String
    var items: [SetlistItem]

    init(
        schemaVersion: Int = currentSchemaVersion,
        id: String,
        name: String,
        items: [SetlistItem]
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.items = items
    }
}

struct SongSection: Codable, Equatable, Sendable {
    var id: String
    var name: String
    var type: SongSectionType
    var cuePackageID: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case cuePackageID = "cuePackageId"
    }

    init(id: String, name: String, type: SongSectionType, cuePackageID: String) {
        self.id = id
        self.name = name
        self.type = type
        self.cuePackageID = cuePackageID
    }
}

struct SongScore: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var id: String
    var artist: String
    var title: String
    var bpm: Double?
    var musicalKey: String?
    var sections: [SongSection]

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id
        case artist
        case title
        case bpm
        case musicalKey = "key"
        case sections
    }

    init(
        schemaVersion: Int = currentSchemaVersion,
        id: String,
        artist: String,
        title: String,
        bpm: Double? = nil,
        musicalKey: String? = nil,
        sections: [SongSection]
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.artist = artist
        self.title = title
        self.bpm = bpm
        self.musicalKey = musicalKey
        self.sections = sections
    }
}

struct CuePackage: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var id: String
    var name: String
    var actions: [EndpointAction]

    init(
        schemaVersion: Int = currentSchemaVersion,
        id: String,
        name: String,
        actions: [EndpointAction]
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.actions = actions
    }
}

struct ShowPreset: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var id: String
    var name: String
    var cuePackageID: String

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id
        case name
        case cuePackageID = "cuePackageId"
    }

    init(
        schemaVersion: Int = currentSchemaVersion,
        id: String,
        name: String,
        cuePackageID: String
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.cuePackageID = cuePackageID
    }
}

struct PresetReference: Codable, Equatable, Sendable {
    var presetID: String
    var label: String?

    enum CodingKeys: String, CodingKey {
        case presetID = "presetId"
        case label
    }

    init(presetID: String, label: String? = nil) {
        self.presetID = presetID
        self.label = label
    }
}

struct ShowDirectorGraph: Equatable, Sendable {
    var show: ShowDocument
    var setlistsByID: [String: Setlist]
    var songsByID: [String: SongScore]
    var cuePackagesByID: [String: CuePackage]
    var presetsByID: [String: ShowPreset]

    init(
        show: ShowDocument,
        setlistsByID: [String: Setlist] = [:],
        songsByID: [String: SongScore] = [:],
        cuePackagesByID: [String: CuePackage] = [:],
        presetsByID: [String: ShowPreset] = [:]
    ) {
        self.show = show
        self.setlistsByID = setlistsByID
        self.songsByID = songsByID
        self.cuePackagesByID = cuePackagesByID
        self.presetsByID = presetsByID
    }
}
