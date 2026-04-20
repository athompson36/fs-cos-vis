import Foundation

enum StageLayoutBackdropSupport {
    private static var stageDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent(AppIdentity.applicationSupportFolderName, isDirectory: true)
            .appendingPathComponent("Stage", isDirectory: true)
    }

    static func copyBackdropToAppSupport(from sourceURL: URL, id: UUID) throws -> String {
        try FileManager.default.createDirectory(at: stageDirectory, withIntermediateDirectories: true)
        let ext = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
        let dest = stageDirectory.appendingPathComponent("\(id.uuidString).\(ext.lowercased())")
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: sourceURL, to: dest)
        return dest.path
    }
}

struct StagePlacement: Codable, Equatable, Sendable {
    var x: Double
    var y: Double
    var rotation: Double

    init(x: Double = 0.5, y: Double = 0.5, rotation: Double = 0) {
        self.x = x
        self.y = y
        self.rotation = rotation
    }
}

struct StageBackdropPlacement: Codable, Equatable, Sendable {
    var isVisible: Bool
    /// Normalized center position in the stage preview.
    var centerX: Double
    var centerY: Double
    /// Relative scalar where 1.0 fills the stage bounds.
    var scale: Double
    var rotation: Double

    init(
        isVisible: Bool = true,
        centerX: Double = 0.5,
        centerY: Double = 0.5,
        scale: Double = 1.0,
        rotation: Double = 0
    ) {
        self.isVisible = isVisible
        self.centerX = centerX
        self.centerY = centerY
        self.scale = scale
        self.rotation = rotation
    }
}

struct StageDimensions: Codable, Equatable, Sendable {
    /// Real stage width in meters.
    var widthMeters: Double
    /// Real stage depth in meters.
    var depthMeters: Double

    init(widthMeters: Double = 12, depthMeters: Double = 8) {
        self.widthMeters = widthMeters
        self.depthMeters = depthMeters
    }
}

struct StagePlotObject: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    /// Template identifier from stage object catalog (e.g. drum_kit).
    var templateID: String
    var label: String
    /// Real-world footprint (meters) before scale multiplier.
    var footprintWidthMeters: Double
    var footprintDepthMeters: Double
    var centerX: Double
    var centerY: Double
    var rotation: Double
    var scale: Double
    var isLocked: Bool

    init(
        id: UUID = UUID(),
        templateID: String,
        label: String,
        footprintWidthMeters: Double,
        footprintDepthMeters: Double,
        centerX: Double = 0.5,
        centerY: Double = 0.5,
        rotation: Double = 0,
        scale: Double = 1,
        isLocked: Bool = false
    ) {
        self.id = id
        self.templateID = templateID
        self.label = label
        self.footprintWidthMeters = footprintWidthMeters
        self.footprintDepthMeters = footprintDepthMeters
        self.centerX = centerX
        self.centerY = centerY
        self.rotation = rotation
        self.scale = scale
        self.isLocked = isLocked
    }

    enum CodingKeys: String, CodingKey {
        case id
        case templateID
        case label
        case footprintWidthMeters
        case footprintDepthMeters
        case centerX
        case centerY
        case rotation
        case scale
        case isLocked
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        templateID = try container.decode(String.self, forKey: .templateID)
        label = try container.decode(String.self, forKey: .label)
        footprintWidthMeters = try container.decode(Double.self, forKey: .footprintWidthMeters)
        footprintDepthMeters = try container.decode(Double.self, forKey: .footprintDepthMeters)
        centerX = try container.decodeIfPresent(Double.self, forKey: .centerX) ?? 0.5
        centerY = try container.decodeIfPresent(Double.self, forKey: .centerY) ?? 0.5
        rotation = try container.decodeIfPresent(Double.self, forKey: .rotation) ?? 0
        scale = try container.decodeIfPresent(Double.self, forKey: .scale) ?? 1
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
    }

    func normalizedFootprint(in dimensions: StageDimensions) -> (width: Double, depth: Double) {
        let widthMeters = max(0.2, footprintWidthMeters * scale)
        let depthMeters = max(0.2, footprintDepthMeters * scale)
        let stageWidth = max(1, dimensions.widthMeters)
        let stageDepth = max(1, dimensions.depthMeters)
        return (widthMeters / stageWidth, depthMeters / stageDepth)
    }
}

struct StageScanCameraPlacement: Codable, Equatable, Sendable {
    var isEnabled: Bool
    var label: String
    /// Camera position normalized in stage space.
    var x: Double
    var y: Double
    /// Heading in stage plane. 0 points upstage.
    var angleDeg: Double
    /// Suggested field-of-view wedge for scan guidance.
    var fovDeg: Double

    init(
        isEnabled: Bool = false,
        label: String = "Scan camera",
        x: Double = 0.2,
        y: Double = 0.1,
        angleDeg: Double = 15,
        fovDeg: Double = 70
    ) {
        self.isEnabled = isEnabled
        self.label = label
        self.x = x
        self.y = y
        self.angleDeg = angleDeg
        self.fovDeg = fovDeg
    }
}

struct StageLayoutDocument: Codable, Equatable, Sendable {
    var version: Int
    /// Optional imported PNG/SVG path in app support (future).
    var backdropAssetPath: String?
    /// Backdrop transform and visibility for stage and 2.5D preview.
    var backdropPlacement: StageBackdropPlacement
    /// Real-world stage dimensions used for auto-scaling plot object footprints.
    var dimensions: StageDimensions
    /// Fixture instance UUID string -> normalized 0...1 stage position.
    var placements: [String: StagePlacement]
    /// Common gear/instrument objects for stage plotting.
    var plotObjects: [StagePlotObject]
    /// Primary camera used for fixture/object detection scan.
    var primaryScanCamera: StageScanCameraPlacement
    /// Optional secondary angled camera (e.g. wireless iOS Continuity Camera).
    var secondaryScanCamera: StageScanCameraPlacement

    static let currentVersion = 1

    init(
        version: Int = currentVersion,
        backdropAssetPath: String? = nil,
        backdropPlacement: StageBackdropPlacement = StageBackdropPlacement(),
        dimensions: StageDimensions = StageDimensions(),
        placements: [String: StagePlacement] = [:],
        plotObjects: [StagePlotObject] = [],
        primaryScanCamera: StageScanCameraPlacement = StageScanCameraPlacement(
            isEnabled: true,
            label: "Primary scan",
            x: 0.18,
            y: 0.1,
            angleDeg: 10,
            fovDeg: 68
        ),
        secondaryScanCamera: StageScanCameraPlacement = StageScanCameraPlacement(
            isEnabled: false,
            label: "Secondary iOS scan",
            x: 0.84,
            y: 0.14,
            angleDeg: -25,
            fovDeg: 64
        )
    ) {
        self.version = version
        self.backdropAssetPath = backdropAssetPath
        self.backdropPlacement = backdropPlacement
        self.dimensions = dimensions
        self.placements = placements
        self.plotObjects = plotObjects
        self.primaryScanCamera = primaryScanCamera
        self.secondaryScanCamera = secondaryScanCamera
    }

    enum CodingKeys: String, CodingKey {
        case version
        case backdropAssetPath
        case backdropPlacement
        case dimensions
        case placements
        case plotObjects
        case primaryScanCamera
        case secondaryScanCamera
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? Self.currentVersion
        backdropAssetPath = try container.decodeIfPresent(String.self, forKey: .backdropAssetPath)
        backdropPlacement = try container.decodeIfPresent(StageBackdropPlacement.self, forKey: .backdropPlacement) ?? StageBackdropPlacement()
        dimensions = try container.decodeIfPresent(StageDimensions.self, forKey: .dimensions) ?? StageDimensions()
        placements = try container.decodeIfPresent([String: StagePlacement].self, forKey: .placements) ?? [:]
        plotObjects = try container.decodeIfPresent([StagePlotObject].self, forKey: .plotObjects) ?? []
        primaryScanCamera = try container.decodeIfPresent(StageScanCameraPlacement.self, forKey: .primaryScanCamera)
            ?? StageScanCameraPlacement(
                isEnabled: true,
                label: "Primary scan",
                x: 0.18,
                y: 0.1,
                angleDeg: 10,
                fovDeg: 68
            )
        secondaryScanCamera = try container.decodeIfPresent(StageScanCameraPlacement.self, forKey: .secondaryScanCamera)
            ?? StageScanCameraPlacement(
                isEnabled: false,
                label: "Secondary iOS scan",
                x: 0.84,
                y: 0.14,
                angleDeg: -25,
                fovDeg: 64
            )
    }
}

enum StageLayoutStore {
    private static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent(AppIdentity.applicationSupportFolderName, isDirectory: true)
            .appendingPathComponent("stage_layout.json")
    }

    static func loadOrDefault() -> StageLayoutDocument {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let doc = try? JSONDecoder().decode(StageLayoutDocument.self, from: data)
        else {
            return StageLayoutDocument()
        }
        return doc
    }

    static func save(_ doc: StageLayoutDocument) throws {
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(doc)
        try data.write(to: fileURL, options: .atomic)
    }
}
