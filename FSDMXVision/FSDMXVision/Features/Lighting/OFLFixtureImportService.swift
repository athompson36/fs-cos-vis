import Foundation

enum OFLImportError: Error {
    case invalidJSON
}

/// Fetch / cache Open Fixture Library JSON and map a mode into `FixtureProfile`.
enum OFLFixtureImportService {
    enum CatalogSource: String, Codable, Equatable, Hashable, Sendable {
        case oflCurated = "ofl_curated"
        case curatedLocal = "curated_local"
    }

    struct CatalogEntry: Codable, Equatable, Hashable, Sendable, Identifiable {
        var id: String { "\(manufacturerSlug)/\(fixtureSlug)" }
        var manufacturerSlug: String
        var manufacturerName: String
        var fixtureSlug: String
        var fixtureName: String
        var categories: [String]
        var isFogRelated: Bool
        var source: CatalogSource

        enum CodingKeys: String, CodingKey {
            case manufacturerSlug
            case manufacturerName
            case fixtureSlug
            case fixtureName
            case categories
            case isFogRelated
            case source
        }

        init(
            manufacturerSlug: String,
            manufacturerName: String,
            fixtureSlug: String,
            fixtureName: String,
            categories: [String],
            isFogRelated: Bool,
            source: CatalogSource
        ) {
            self.manufacturerSlug = manufacturerSlug
            self.manufacturerName = manufacturerName
            self.fixtureSlug = fixtureSlug
            self.fixtureName = fixtureName
            self.categories = categories
            self.isFogRelated = isFogRelated
            self.source = source
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            manufacturerSlug = try container.decode(String.self, forKey: .manufacturerSlug)
            manufacturerName = try container.decode(String.self, forKey: .manufacturerName)
            fixtureSlug = try container.decode(String.self, forKey: .fixtureSlug)
            fixtureName = try container.decode(String.self, forKey: .fixtureName)
            categories = try container.decode([String].self, forKey: .categories)
            isFogRelated = try container.decode(Bool.self, forKey: .isFogRelated)
            source = try container.decodeIfPresent(CatalogSource.self, forKey: .source) ?? .oflCurated
        }
    }

    struct CatalogCache: Codable, Equatable, Sendable {
        var generatedAt: Date
        var entries: [CatalogEntry]
    }

    struct ManufacturerSeed: Codable, Equatable, Hashable, Sendable {
        var slug: String
        var displayName: String
    }

    private static var cacheDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent(AppIdentity.applicationSupportFolderName, isDirectory: true)
            .appendingPathComponent("FixtureLibrary", isDirectory: true)
    }

    static var fixtureCatalogCacheURL: URL {
        cacheDirectory.appendingPathComponent("catalog-curated.json")
    }

    /// Curated top manufacturers (lighting + fog/haze) for practical offline-first workflows.
    static var curatedManufacturerSeeds: [ManufacturerSeed] {
        [
            ManufacturerSeed(slug: "adj", displayName: "ADJ"),
            ManufacturerSeed(slug: "chauvet-dj", displayName: "Chauvet DJ"),
            ManufacturerSeed(slug: "american-dj", displayName: "American DJ"),
            ManufacturerSeed(slug: "blizzard", displayName: "Blizzard"),
            ManufacturerSeed(slug: "martin", displayName: "Martin"),
            ManufacturerSeed(slug: "robe", displayName: "Robe"),
            ManufacturerSeed(slug: "ayrton", displayName: "Ayrton"),
            ManufacturerSeed(slug: "elation", displayName: "Elation"),
            ManufacturerSeed(slug: "cameo", displayName: "Cameo"),
            ManufacturerSeed(slug: "etc", displayName: "ETC"),
            ManufacturerSeed(slug: "clay-paky", displayName: "Clay Paky"),
            ManufacturerSeed(slug: "showtec", displayName: "Showtec"),
            ManufacturerSeed(slug: "eurolite", displayName: "Eurolite"),
            ManufacturerSeed(slug: "stairville", displayName: "Stairville"),
            ManufacturerSeed(slug: "antari", displayName: "Antari"),
            ManufacturerSeed(slug: "look-solutions", displayName: "Look Solutions"),
            ManufacturerSeed(slug: "hazebase", displayName: "HazeBase"),
            ManufacturerSeed(slug: "magicfx", displayName: "MAGICFX"),
            ManufacturerSeed(slug: "ultratec", displayName: "Ultratec"),
        ]
    }

    /// `manufacturer` and `fixture` match OFL path segments, e.g. `cameo` + `hydrabeam-400`.
    static func cacheURL(manufacturer: String, fixture: String) -> URL {
        cacheDirectory
            .appendingPathComponent(manufacturer, isDirectory: true)
            .appendingPathComponent("\(fixture).json")
    }

    static func fetchRawFixture(manufacturer: String, fixture: String) async throws -> Data {
        if let bundled = Bundle.main.url(forResource: fixture, withExtension: "json", subdirectory: "Fixtures/\(manufacturer)") {
            return try Data(contentsOf: bundled)
        }
        let local = cacheURL(manufacturer: manufacturer, fixture: fixture)
        if FileManager.default.fileExists(atPath: local.path) {
            return try Data(contentsOf: local)
        }
        let man = manufacturer.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? manufacturer
        let fix = fixture.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fixture
        let remote = URL(
            string: "https://raw.githubusercontent.com/OpenLightingProject/open-fixture-library/master/fixtures/\(man)/\(fix).json"
        )!
        let (data, resp) = try await URLSession.shared.data(from: remote)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        try FileManager.default.createDirectory(at: local.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: local, options: .atomic)
        return data
    }

    /// Fetches OFL register and builds a curated local catalog for quick fixture browsing/import.
    static func syncCuratedCatalog(limitPerManufacturer: Int = 60) async throws -> CatalogCache {
        let register = try await fetchFixtureRegister()
        let cache = buildUnifiedCatalog(from: register, limitPerManufacturer: limitPerManufacturer)
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try JSONEncoder().encode(cache).write(to: fixtureCatalogCacheURL, options: .atomic)
        return cache
    }

    static func buildCuratedCatalog(from registerData: Data, limitPerManufacturer: Int = 60) throws -> CatalogCache {
        let register = try JSONDecoder().decode(FixtureRegister.self, from: registerData)
        return buildUnifiedCatalog(from: register, limitPerManufacturer: limitPerManufacturer)
    }

    private static func buildCuratedCatalog(from register: FixtureRegister, limitPerManufacturer: Int) -> CatalogCache {
        let curatedSlugs = Set(curatedManufacturerSeeds.map(\.slug))
        var manufacturerNameBySlug = register.manufacturers
        for seed in curatedManufacturerSeeds where manufacturerNameBySlug[seed.slug] == nil {
            manufacturerNameBySlug[seed.slug] = seed.displayName
        }
        var entries: [CatalogEntry] = []
        var perManufacturerCount: [String: Int] = [:]
        for (fixturePath, fixtureMeta) in register.fixtures {
            let parts = fixturePath.split(separator: "/").map(String.init)
            guard parts.count == 2 else { continue }
            let manufacturerSlug = parts[0]
            guard curatedSlugs.contains(manufacturerSlug) else { continue }
            let fixtureSlug = parts[1]
            let count = perManufacturerCount[manufacturerSlug] ?? 0
            guard count < limitPerManufacturer else { continue }
            let cats = fixtureMeta.categories
            let fog = isFogRelated(fixtureName: fixtureMeta.name, categories: cats)
            entries.append(
                CatalogEntry(
                    manufacturerSlug: manufacturerSlug,
                    manufacturerName: manufacturerNameBySlug[manufacturerSlug] ?? manufacturerSlug,
                    fixtureSlug: fixtureSlug,
                    fixtureName: fixtureMeta.name,
                    categories: cats,
                    isFogRelated: fog,
                    source: .oflCurated
                )
            )
            perManufacturerCount[manufacturerSlug] = count + 1
        }
        // Favor fog/haze entries first, then name sort.
        entries.sort {
            if $0.isFogRelated != $1.isFogRelated { return $0.isFogRelated && !$1.isFogRelated }
            if $0.manufacturerName != $1.manufacturerName { return $0.manufacturerName < $1.manufacturerName }
            return $0.fixtureName < $1.fixtureName
        }
        return CatalogCache(generatedAt: Date(), entries: entries)
    }

    private static func buildUnifiedCatalog(from register: FixtureRegister, limitPerManufacturer: Int) -> CatalogCache {
        var merged = buildCuratedCatalog(from: register, limitPerManufacturer: limitPerManufacturer).entries
        merged = mergeCatalogEntries(primary: merged, secondary: bundledCuratedFallbackCatalog())
        merged.sort {
            if $0.isFogRelated != $1.isFogRelated { return $0.isFogRelated && !$1.isFogRelated }
            if $0.manufacturerName != $1.manufacturerName { return $0.manufacturerName < $1.manufacturerName }
            return $0.fixtureName < $1.fixtureName
        }
        return CatalogCache(generatedAt: Date(), entries: merged)
    }

    private static func mergeCatalogEntries(primary: [CatalogEntry], secondary: [CatalogEntry]) -> [CatalogEntry] {
        var byKey: [String: CatalogEntry] = [:]
        for entry in primary {
            byKey[entry.id] = entry
        }
        for entry in secondary where byKey[entry.id] == nil {
            byKey[entry.id] = entry
        }
        return Array(byKey.values)
    }

    static func bundledCuratedFallbackCatalog() -> [CatalogEntry] {
        curatedFallbackFixtures.map { fixture in
            CatalogEntry(
                manufacturerSlug: fixture.manufacturerSlug,
                manufacturerName: fixture.manufacturerName,
                fixtureSlug: fixture.fixtureSlug,
                fixtureName: fixture.fixtureName,
                categories: fixture.categories,
                isFogRelated: isFogRelated(fixtureName: fixture.fixtureName, categories: fixture.categories),
                source: .curatedLocal
            )
        }
    }

    static func loadCuratedCatalog() -> CatalogCache? {
        guard let data = try? Data(contentsOf: fixtureCatalogCacheURL) else { return nil }
        return try? JSONDecoder().decode(CatalogCache.self, from: data)
    }

    static func buildProfile(
        manufacturer: String,
        fixture: String,
        data: Data,
        modeIndex: Int = 0
    ) throws -> FixtureProfile {
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OFLImportError.invalidJSON
        }
        let modes = obj["modes"] as? [[String: Any]] ?? []
        guard modeIndex >= 0, modeIndex < modes.count else {
            throw OFLImportError.invalidJSON
        }
        let mode = modes[modeIndex]
        let modeName = mode["name"] as? String ?? "Mode \(modeIndex)"
        let channelNames = mode["channels"] as? [String] ?? []

        let available = obj["availableChannels"] as? [String: [String: Any]] ?? [:]
        var defs: [FixtureChannelDef] = []
        var caps: [String] = []
        for chName in channelNames {
            let cap = summarizeChannel(chName: chName, available: available)
            caps.append(cap)
            defs.append(FixtureChannelDef(label: chName, role: inferRole(chName)))
        }
        let niceName: String = {
            if let n = obj["name"] as? String { return n }
            return "\(manufacturer)/\(fixture)"
        }()
        return FixtureProfile(
            name: "\(niceName) — \(modeName)",
            channels: defs,
            oflFixtureKey: "\(manufacturer)/\(fixture)",
            oflModeName: modeName,
            channelCapabilities: caps
        )
    }

    private static func summarizeChannel(chName: String, available: [String: [String: Any]]) -> String {
        guard let ch = available[chName] else { return chName }
        var parts: [String] = []
        if let t = ch["type"] as? String { parts.append("type:\(t)") }
        if let cap = ch["capability"] as? [String: Any] {
            if let mn = cap["min"] { parts.append("min:\(mn)") }
            if let mx = cap["max"] { parts.append("max:\(mx)") }
        }
        return parts.isEmpty ? chName : "\(chName) (\(parts.joined(separator: ", ")))"
    }

    private static func inferRole(_ raw: String) -> FixtureChannelRole {
        let s = raw.lowercased()
        if s.contains("dim") || s.contains("intensity") { return .intensity }
        if s.contains("red") || s == "r" { return .red }
        if s.contains("green") || s == "g" { return .green }
        if s.contains("blue") || s == "b" { return .blue }
        if s.contains("white") || s.contains("cw") || s.contains("ww") { return .white }
        if s.contains("amber") { return .amber }
        if s.contains("uv") || s.contains("blacklight") { return .uv }
        if s.contains("strobe") || s.contains("shutter") { return .strobe }
        if s.contains("pan") { return .pan }
        if s.contains("tilt") { return .tilt }
        if s.contains("haze") || s.contains("fog") { return .hazeOutput }
        if s.contains("fan") { return .hazeFan }
        if s.contains("pump") { return .hazePump }
        return .generic
    }

    private struct FixtureRegister: Decodable {
        struct FixtureMeta: Decodable {
            var name: String
            var categories: [String]
        }
        var manufacturers: [String: String]
        var fixtures: [String: FixtureMeta]
    }

    private struct CuratedFallbackFixture: Codable {
        var manufacturerSlug: String
        var manufacturerName: String
        var fixtureSlug: String
        var fixtureName: String
        var categories: [String]
    }

    private static let curatedFallbackFixtures: [CuratedFallbackFixture] = [
        CuratedFallbackFixture(manufacturerSlug: "chauvet-dj", manufacturerName: "Chauvet DJ", fixtureSlug: "intimidator-spot-260x", fixtureName: "Intimidator Spot 260X", categories: ["Moving Head"]),
        CuratedFallbackFixture(manufacturerSlug: "adj", manufacturerName: "ADJ", fixtureSlug: "focus-spot-4z", fixtureName: "Focus Spot 4Z", categories: ["Moving Head"]),
        CuratedFallbackFixture(manufacturerSlug: "robe", manufacturerName: "Robe", fixtureSlug: "megapointe", fixtureName: "MegaPointe", categories: ["Moving Head"]),
        CuratedFallbackFixture(manufacturerSlug: "etc", manufacturerName: "ETC", fixtureSlug: "source-four-led-series-2", fixtureName: "Source Four LED Series 2", categories: ["Color Changer"]),
        CuratedFallbackFixture(manufacturerSlug: "clay-paky", manufacturerName: "Clay Paky", fixtureSlug: "sharpy-plus", fixtureName: "Sharpy Plus", categories: ["Moving Head"]),
        CuratedFallbackFixture(manufacturerSlug: "elation", manufacturerName: "Elation", fixtureSlug: "platinum-beam-5r-pro", fixtureName: "Platinum Beam 5R Pro", categories: ["Moving Head"]),
        CuratedFallbackFixture(manufacturerSlug: "antari", manufacturerName: "Antari", fixtureSlug: "hz-500", fixtureName: "HZ-500 Hazer", categories: ["Effect"]),
        CuratedFallbackFixture(manufacturerSlug: "look-solutions", manufacturerName: "Look Solutions", fixtureSlug: "unique-2-1", fixtureName: "Unique 2.1 Hazer", categories: ["Effect"]),
        CuratedFallbackFixture(manufacturerSlug: "magicfx", manufacturerName: "MAGICFX", fixtureSlug: "stadium-shot-ii", fixtureName: "Stadium Shot II", categories: ["Effect"]),
        CuratedFallbackFixture(manufacturerSlug: "ultratec", manufacturerName: "Ultratec", fixtureSlug: "radiance-hazer", fixtureName: "Radiance Hazer", categories: ["Effect"]),
        // Starter rig — Chauvet / American DJ (OFL remote when present; see docs/fixture-source-provenance.md)
        CuratedFallbackFixture(manufacturerSlug: "chauvet-dj", manufacturerName: "Chauvet DJ", fixtureSlug: "hurricane-haze-1dx", fixtureName: "Hurricane Haze 1DX", categories: ["Effect"]),
        CuratedFallbackFixture(manufacturerSlug: "chauvet-dj", manufacturerName: "Chauvet DJ", fixtureSlug: "slimpar-pro-rgba", fixtureName: "SlimPAR Pro RGBA", categories: ["Color Changer"]),
        CuratedFallbackFixture(manufacturerSlug: "chauvet-dj", manufacturerName: "Chauvet DJ", fixtureSlug: "slimpar-t12-usb", fixtureName: "SlimPAR T12 USB", categories: ["Color Changer"]),
        CuratedFallbackFixture(manufacturerSlug: "american-dj", manufacturerName: "American DJ", fixtureSlug: "mega-bar-50rgb", fixtureName: "Mega Bar 50RGB", categories: ["Color Changer"]),
        CuratedFallbackFixture(manufacturerSlug: "american-dj", manufacturerName: "American DJ", fixtureSlug: "inno-pocket-fusion", fixtureName: "Inno Pocket Fusion", categories: ["Moving Head"]),
        CuratedFallbackFixture(manufacturerSlug: "american-dj", manufacturerName: "American DJ", fixtureSlug: "inno-pocket-beam-q4", fixtureName: "Inno Pocket Beam Q4", categories: ["Moving Head"]),
        // Bundled OFL-shaped JSON (app Resources); used when remote OFL fetch is unavailable
        CuratedFallbackFixture(manufacturerSlug: "elation", manufacturerName: "Elation", fixtureSlug: "dp-415", fixtureName: "DP-415", categories: ["Dimmer"]),
        CuratedFallbackFixture(manufacturerSlug: "elation", manufacturerName: "Elation", fixtureSlug: "dp-415r", fixtureName: "DP-415R", categories: ["Dimmer"]),
        CuratedFallbackFixture(manufacturerSlug: "chauvet-dj", manufacturerName: "Chauvet DJ", fixtureSlug: "scorpion-dual", fixtureName: "Scorpion Dual", categories: ["Effect"]),
        CuratedFallbackFixture(manufacturerSlug: "chauvet-dj", manufacturerName: "Chauvet DJ", fixtureSlug: "storm-fx-rgb", fixtureName: "Storm FX RGB", categories: ["Effect"]),
        CuratedFallbackFixture(manufacturerSlug: "chauvet-dj", manufacturerName: "Chauvet DJ", fixtureSlug: "circus-2-0-irc", fixtureName: "Circus 2.0 IRC", categories: ["Effect"]),
        CuratedFallbackFixture(manufacturerSlug: "chauvet-dj", manufacturerName: "Chauvet DJ", fixtureSlug: "slimpar-64-rgba", fixtureName: "SlimPAR 64 RGBA", categories: ["Color Changer"]),
        CuratedFallbackFixture(manufacturerSlug: "chauvet-dj", manufacturerName: "Chauvet DJ", fixtureSlug: "slimpar-56-ils", fixtureName: "SlimPAR 56 ILS", categories: ["Color Changer"]),
        CuratedFallbackFixture(manufacturerSlug: "american-dj", manufacturerName: "American DJ", fixtureSlug: "sparkle", fixtureName: "Sparkle", categories: ["Effect"]),
        CuratedFallbackFixture(manufacturerSlug: "american-dj", manufacturerName: "American DJ", fixtureSlug: "p64-led", fixtureName: "P64 LED", categories: ["Color Changer"]),
        CuratedFallbackFixture(manufacturerSlug: "american-dj", manufacturerName: "American DJ", fixtureSlug: "innopocket-scan", fixtureName: "Inno Pocket Scan", categories: ["Moving Head"]),
        CuratedFallbackFixture(manufacturerSlug: "blizzard", manufacturerName: "Blizzard", fixtureSlug: "kaptivator-3d-rgb", fixtureName: "Kaptivator 3D RGB Laser", categories: ["Effect"]),
    ]

    private static func fetchFixtureRegister() async throws -> FixtureRegister {
        let local = cacheDirectory.appendingPathComponent("fixtures-register.json")
        if FileManager.default.fileExists(atPath: local.path),
           let data = try? Data(contentsOf: local),
           let decoded = try? JSONDecoder().decode(FixtureRegister.self, from: data) {
            return decoded
        }
        let remote = URL(string: "https://raw.githubusercontent.com/OpenLightingProject/open-fixture-library/master/fixtures/register.json")!
        let (data, resp) = try await URLSession.shared.data(from: remote)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try data.write(to: local, options: .atomic)
        return try JSONDecoder().decode(FixtureRegister.self, from: data)
    }

    private static func isFogRelated(fixtureName: String, categories: [String]) -> Bool {
        let n = fixtureName.lowercased()
        if n.contains("fog") || n.contains("haze") || n.contains("faze") || n.contains("smoke") {
            return true
        }
        return categories.map { $0.lowercased() }.contains {
            $0.contains("fog") || $0.contains("haze") || $0.contains("effect")
        }
    }
}
