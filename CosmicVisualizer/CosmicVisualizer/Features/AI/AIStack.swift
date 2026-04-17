import Foundation
import Security

// MARK: - Keychain (LLM API key)

enum LLMKeychain {
    private static let service = "com.cosmicvisualizer.llm.v1"
    private static let account = "apiKey"

    static func saveAPIKey(_ value: String?) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        guard let value, !value.isEmpty, let data = value.data(using: .utf8) else { return }
        var add = query
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }

    static func loadAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Effect expectation copy (role + OFL hints)

enum FXExpectationDescriber {
    static func describe(role: FixtureChannelRole, capability: String?) -> String {
        let cap = capability?.trimmingCharacters(in: .whitespacesAndNewlines)
        let capBit = (cap?.isEmpty == false) ? " Library note: \(cap!)." : ""
        switch role {
        case .intensity: return "Master brightness / dimmer; higher values increase overall output.\(capBit)"
        case .red, .green, .blue: return "Additive RGB component; pushes color toward \(role).\(capBit)"
        case .white: return "Cool or warm white LED channel depending on fixture.\(capBit)"
        case .amber: return "Warms the beam; often mixed with RGB for better skin tones.\(capBit)"
        case .uv: return "Ultraviolet / blacklight channel; visible glow on fluorescent materials.\(capBit)"
        case .strobe: return "Strobe rate or shutter; expect intermittent flashes at high values.\(capBit)"
        case .pan: return "Horizontal beam aim; sweeps left/right.\(capBit)"
        case .tilt: return "Vertical beam aim; sweeps floor to ceiling.\(capBit)"
        case .hazeOutput: return "Haze or fog density output.\(capBit)"
        case .hazeFan: return "Fan speed affecting throw and dispersion.\(capBit)"
        case .hazePump: return "Pump / fluid drive; often precedes visible haze.\(capBit)"
        case .generic: return "Generic DMX channel; consult fixture manual.\(capBit)"
        }
    }
}

// MARK: - Machine context (machine.json)

struct MachineContextRoot: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var generatedAt: Date
    var venue: VenueMetadata?
    var show: ShowMetadata?
    var sceneSummary: MachineSceneSummary
    var lighting: MachineLightingSection
    var backdrop: MachineBackdropSection
    var stage: MachineStageSection
    var performanceFlags: MachinePerformanceFlags
    var calibrationPath: String?
}

struct MachineBackdropSection: Codable, Equatable, Sendable {
    var cueNames: [String]
    var activeCueIndex: Int?
    var bookmarkedCueIds: [UUID]
}

struct MachineSceneSummary: Codable, Equatable, Sendable {
    var currentSceneIndex: Int
    var currentSceneName: String
    var sceneCount: Int
    var selectedPaletteID: UUID?
    var overlayEnabled: Bool
    var overlayAssetPaths: [String]
}

struct MachineLightingSection: Codable, Equatable, Sendable {
    var activeCueIndex: Int?
    var activeCueName: String?
    var cues: [MachineCueSummary]
    var lightingCueBookmarks: [UUID]
    var fixtures: [MachineFixture]
    var modulationModulatorCount: Int
}

struct MachineCueSummary: Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var fadeSeconds: Double
    var previewThumbnailPath: String?
}

struct MachineFixture: Codable, Equatable, Sendable {
    var id: UUID
    var profileName: String
    var universe: UInt8
    var startAddress: Int
    var oflFixtureKey: String?
    var oflModeName: String?
    var channels: [MachineFixtureChannel]
}

struct MachineFixtureChannel: Codable, Equatable, Sendable {
    var index: Int
    var dmxChannel: Int
    var label: String
    var role: FixtureChannelRole
    var capability: String?
    var expectation: String
}

struct MachineStageSection: Codable, Equatable, Sendable {
    var backdropAssetPath: String?
    var placements: [String: StagePlacement]
}

struct MachinePerformanceFlags: Codable, Equatable, Sendable {
    var lightingStripEnabled: Bool
    var backdropStripEnabled: Bool
    var hybridAIEnabled: Bool
}

struct ShowContextSnapshot: Sendable {
    var projectMeta: ShowProjectDocument?
    var dmxPatch: DMXPatchDocument
    var lightingCues: LightingCueDocument
    var backdropCues: BackdropCueDocument
    var modulation: ModulationDocument
    var stageLayout: StageLayoutDocument
    var sceneIndex: Int
    var sceneName: String
    var sceneCount: Int
    var selectedPaletteID: UUID?
    var overlayEnabled: Bool
    var overlays: [OverlayAsset]
    var performanceFlags: MachinePerformanceFlags
    var calibrationRelativePath: String?
}

enum ShowContextGenerator {
    static let schemaVersion = 1

    static func buildMachineRoot(from snap: ShowContextSnapshot) -> MachineContextRoot {
        let patch = snap.dmxPatch
        let lc = snap.lightingCues
        let activeName = lc.activeCueIndex.flatMap { i in lc.cues.indices.contains(i) ? lc.cues[i].name : nil }
        let fixtures: [MachineFixture] = patch.instances.map { inst in
            let profile = patch.profile(id: inst.profileID)
            let caps = profile?.channelCapabilities
            let chans: [MachineFixtureChannel] = (profile?.channels ?? []).enumerated().map { idx, def in
                let cap = (caps != nil && idx < caps!.count) ? caps![idx] : nil
                let dmxCh = inst.startAddress + idx
                return MachineFixtureChannel(
                    index: idx,
                    dmxChannel: dmxCh,
                    label: def.label,
                    role: def.role,
                    capability: cap,
                    expectation: FXExpectationDescriber.describe(role: def.role, capability: cap)
                )
            }
            return MachineFixture(
                id: inst.id,
                profileName: profile?.name ?? "Unknown",
                universe: inst.universe,
                startAddress: inst.startAddress,
                oflFixtureKey: profile?.oflFixtureKey,
                oflModeName: profile?.oflModeName,
                channels: chans
            )
        }
        let cueSummaries = lc.cues.map {
            MachineCueSummary(id: $0.id, name: $0.name, fadeSeconds: $0.fadeSeconds, previewThumbnailPath: $0.previewThumbnailPath)
        }
        return MachineContextRoot(
            schemaVersion: Self.schemaVersion,
            generatedAt: Date(),
            venue: snap.projectMeta?.venue,
            show: snap.projectMeta?.show,
            sceneSummary: MachineSceneSummary(
                currentSceneIndex: snap.sceneIndex,
                currentSceneName: snap.sceneName,
                sceneCount: snap.sceneCount,
                selectedPaletteID: snap.selectedPaletteID,
                overlayEnabled: snap.overlayEnabled,
                overlayAssetPaths: snap.overlays.map(\.filePath)
            ),
            lighting: MachineLightingSection(
                activeCueIndex: lc.activeCueIndex,
                activeCueName: activeName,
                cues: cueSummaries,
                lightingCueBookmarks: lc.bookmarkedCueIds,
                fixtures: fixtures,
                modulationModulatorCount: snap.modulation.modulators.count
            ),
            backdrop: MachineBackdropSection(
                cueNames: snap.backdropCues.cues.map(\.name),
                activeCueIndex: snap.backdropCues.activeCueIndex,
                bookmarkedCueIds: snap.backdropCues.bookmarkedCueIds
            ),
            stage: MachineStageSection(
                backdropAssetPath: snap.stageLayout.backdropAssetPath,
                placements: snap.stageLayout.placements
            ),
            performanceFlags: snap.performanceFlags,
            calibrationPath: snap.calibrationRelativePath
        )
    }

    static func encodeMachineJSON(root: MachineContextRoot) throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return try enc.encode(root)
    }

    static func buildMarkdownDMXUniverse(root: MachineContextRoot) -> String {
        var lines: [String] = []
        lines.append("# DMX universe summary")
        lines.append("")
        lines.append("- Generated: \(ISO8601DateFormatter().string(from: root.generatedAt))")
        if let v = root.venue { lines.append("- Venue: \(v.name)") }
        if let s = root.show { lines.append("- Show: \(s.title)") }
        lines.append("- Active lighting cue: \(root.lighting.activeCueName ?? "none") (index: \(root.lighting.activeCueIndex.map(String.init) ?? "nil"))")
        lines.append("")
        lines.append("## Fixtures")
        for fx in root.lighting.fixtures {
            lines.append("### \(fx.profileName) @ \(fx.startAddress) (id \(fx.id.uuidString.prefix(8))…)")
            if let k = fx.oflFixtureKey { lines.append("- OFL: `\(k)` mode `\(fx.oflModeName ?? "?")`") }
            for ch in fx.channels {
                lines.append("- ch \(ch.dmxChannel): \(ch.label) [\(ch.role.rawValue)] — \(ch.expectation)")
            }
            lines.append("")
        }
        lines.append("## Scene")
        let ss = root.sceneSummary
        lines.append("- \(ss.currentSceneName) (\(ss.currentSceneIndex + 1)/\(ss.sceneCount))")
        lines.append("- Overlays: \(ss.overlayEnabled ? "on" : "off")")
        return lines.joined(separator: "\n")
    }

    static func generate(snap: ShowContextSnapshot) throws -> (json: Data, markdown: String) {
        let root = buildMachineRoot(from: snap)
        let json = try encodeMachineJSON(root: root)
        let md = buildMarkdownDMXUniverse(root: root)
        return (json, md)
    }
}

// MARK: - Context on disk

enum ShowContextDiskLayout {
    static let machineFilename = "machine.json"
    static let markdownFilename = "dmx_universe.md"
    static let calibrationFilename = "calibration.json"

    static func defaultContextDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CosmicVisualizer", isDirectory: true)
            .appendingPathComponent("context", isDirectory: true)
    }

    static func write(json: Data, markdown: String, into folder: URL) throws {
        let ctx = folder.appendingPathComponent("context", isDirectory: true)
        try FileManager.default.createDirectory(at: ctx, withIntermediateDirectories: true)
        try json.write(to: ctx.appendingPathComponent(machineFilename), options: .atomic)
        try markdown.data(using: .utf8)?.write(to: ctx.appendingPathComponent(markdownFilename), options: .atomic)
    }
}

// MARK: - Tool registry (local, deterministic)

enum AIToolExecutionError: Error, LocalizedError {
    case unknownTool(String)
    case invalidArguments(String)
    case patchConflict([String])

    var errorDescription: String? {
        switch self {
        case .unknownTool(let n): return "Unknown tool: \(n)"
        case .invalidArguments(let m): return m
        case .patchConflict(let lines): return lines.joined(separator: "\n")
        }
    }
}

enum AIToolRegistry {
    static func execute(
        name: String,
        argumentsJSON: String?,
        model: AppModel,
        copilot: LightingCopilotService
    ) throws -> String {
        let args = parseJSONObject(argumentsJSON) ?? [:]
        switch name {
        case "refresh_context":
            model.exportAIContextNow()
            return "context_refreshed"
        case "set_active_lighting_cue_index":
            if args["index"] == nil || args["index"] is NSNull {
                model.setActiveLightingCueIndex(nil)
                return "cleared_active_cue"
            }
            guard let raw = args["index"], let i = intValue(raw) else {
                throw AIToolExecutionError.invalidArguments("index must be int or null")
            }
            model.setActiveLightingCueIndex(i)
            return "active_lighting_cue=\(i)"
        case "set_active_backdrop_cue_index":
            if args["index"] == nil || args["index"] is NSNull {
                model.setActiveBackdropCueIndex(nil)
                return "cleared_backdrop_cue"
            }
            guard let raw = args["index"], let i = intValue(raw) else {
                throw AIToolExecutionError.invalidArguments("index must be int or null")
            }
            model.setActiveBackdropCueIndex(i)
            return "active_backdrop_cue=\(i)"
        case "apply_dmx_patch_document":
            guard let s = args["patch_json"] as? String else {
                throw AIToolExecutionError.invalidArguments("patch_json required")
            }
            let data = Data(s.utf8)
            let doc = try JSONDecoder().decode(DMXPatchDocument.self, from: data)
            let conflicts = DMXPatchAudit.universeZeroConflictMessages(patch: doc)
            if !conflicts.isEmpty { throw AIToolExecutionError.patchConflict(conflicts) }
            model.applyDMXPatchDocument(doc)
            return "dmx_patch_applied"
        case "append_lighting_cues_json":
            guard let s = args["cues_json"] as? String else {
                throw AIToolExecutionError.invalidArguments("cues_json required")
            }
            let data = Data(s.utf8)
            let extra = try JSONDecoder().decode([LightingCue].self, from: data)
            model.appendLightingCues(extra)
            return "cues_appended_count=\(extra.count)"
        case "export_fixture_ofl_stub":
            let key = args["ofl_key"] as? String ?? "unknown/fixture"
            return "ofl://\(key) (use Import fixture from library in Lighting workspace)"
        default:
            throw AIToolExecutionError.unknownTool(name)
        }
    }

    private static func parseJSONObject(_ json: String?) -> [String: Any]? {
        guard let json, let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return json == nil || json == "" ? [:] : nil
        }
        return obj
    }

    private static func intValue(_ any: Any) -> Int? {
        if let i = any as? Int { return i }
        if let d = any as? Double { return Int(d) }
        if let s = any as? String { return Int(s) }
        return nil
    }

    /// Parses assistant message body into tool calls `{name, arguments}`.
    static func parseToolCalls(from text: String) throws -> [(name: String, argumentsJSON: String?)] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let calls = root["tool_calls"] as? [[String: Any]]
        else {
            throw AIToolExecutionError.invalidArguments("Expected JSON with tool_calls array")
        }
        return try calls.map { dict in
            guard let name = dict["name"] as? String else {
                throw AIToolExecutionError.invalidArguments("tool call missing name")
            }
            let args = dict["arguments"]
            let argsJSON: String?
            if let a = args as? [String: Any] {
                argsJSON = String(data: try JSONSerialization.data(withJSONObject: a), encoding: .utf8)
            } else if let s = args as? String {
                argsJSON = s
            } else {
                argsJSON = nil
            }
            return (name, argsJSON)
        }
    }
}

// MARK: - LLM client (optional cloud)

struct LLMChatClient {
    struct Settings: Sendable {
        var provider: String
        var model: String
        var baseURL: String?
    }

    func complete(
        userPrompt: String,
        systemPrompt: String,
        contextFiles: [(name: String, content: String)],
        apiKey: String,
        settings: Settings
    ) async throws -> String {
        let provider = settings.provider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base = settings.baseURL?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? (provider == "anthropic" || provider == "claude"
                ? "https://api.anthropic.com/v1/messages"
                : "https://api.openai.com/v1/chat/completions")
        guard let url = URL(string: base) else {
            throw URLError(.badURL)
        }
        var ctxBlock = ""
        for f in contextFiles {
            ctxBlock += "\n### \(f.name)\n\(f.content)\n"
        }
        let userBody = "Context files:\n\(ctxBlock)\n\nUser request:\n\(userPrompt)"
        let body: [String: Any]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if provider == "anthropic" || provider == "claude" {
            body = [
                "model": settings.model,
                "max_tokens": 1200,
                "temperature": 0.1,
                "system": systemPrompt,
                "messages": [
                    ["role": "user", "content": userBody],
                ],
            ]
            req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        } else {
            body = [
                "model": settings.model,
                "temperature": 0.1,
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": userBody],
                ],
            ]
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            let s = String(data: data, encoding: .utf8) ?? ""
            throw AIToolExecutionError.invalidArguments("LLM HTTP error: \(s.prefix(200))")
        }
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if provider == "anthropic" || provider == "claude" {
            guard
                let root,
                let content = root["content"] as? [[String: Any]]
            else {
                throw AIToolExecutionError.invalidArguments("Claude response parse failed")
            }
            let text = content.compactMap { $0["text"] as? String }.joined(separator: "\n")
            guard !text.isEmpty else {
                throw AIToolExecutionError.invalidArguments("Claude returned empty text")
            }
            return text
        }
        guard
            let root,
            let choices = root["choices"] as? [[String: Any]],
            let msg = choices.first?["message"] as? [String: Any],
            let content = msg["content"] as? String
        else {
            throw AIToolExecutionError.invalidArguments("LLM response parse failed")
        }
        return content
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
