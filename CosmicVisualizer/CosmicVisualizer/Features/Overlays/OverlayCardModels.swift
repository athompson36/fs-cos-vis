import Foundation

/// Vector-ish overlay card layers for composite / SwiftUI overlay.
enum OverlayCardShapeKind: String, Codable, Sendable {
    case rect
    case ellipse
    case path
}

struct OverlayCardShape: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var kind: OverlayCardShapeKind
    /// Normalized 0...1 in card space.
    var frame: CGRectCodable
    var fillColorRGBA: [Double]
    var strokeColorRGBA: [Double]?
    var strokeWidth: Double
    /// SVG path d-string when kind == .path
    var pathData: String?

    init(
        id: UUID = UUID(),
        kind: OverlayCardShapeKind,
        frame: CGRectCodable = CGRectCodable(x: 0, y: 0, width: 1, height: 1),
        fillColorRGBA: [Double] = [1, 1, 1, 1],
        strokeColorRGBA: [Double]? = nil,
        strokeWidth: Double = 0,
        pathData: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.frame = frame
        self.fillColorRGBA = fillColorRGBA
        self.strokeColorRGBA = strokeColorRGBA
        self.strokeWidth = strokeWidth
        self.pathData = pathData
    }
}

struct OverlayCardTextLayer: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var text: String
    var fontName: String
    var fontSize: Double
    var frame: CGRectCodable
    var colorRGBA: [Double]

    init(
        id: UUID = UUID(),
        text: String,
        fontName: String = ".AppleSystemUIFont",
        fontSize: Double = 24,
        frame: CGRectCodable = CGRectCodable(x: 0.1, y: 0.4, width: 0.8, height: 0.2),
        colorRGBA: [Double] = [1, 1, 1, 1]
    ) {
        self.id = id
        self.text = text
        self.fontName = fontName
        self.fontSize = fontSize
        self.frame = frame
        self.colorRGBA = colorRGBA
    }
}

struct CGRectCodable: Codable, Equatable, Sendable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

struct OverlayCardDocument: Codable, Equatable, Sendable {
    static let currentVersion = 1

    var version: Int
    var name: String
    var shapes: [OverlayCardShape]
    var texts: [OverlayCardTextLayer]
    /// Optional imported SVG raw (for round-trip; rendering uses shapes).
    var importedSVGSource: String?

    init(
        version: Int = currentVersion,
        name: String = "Overlay card",
        shapes: [OverlayCardShape] = [],
        texts: [OverlayCardTextLayer] = [],
        importedSVGSource: String? = nil
    ) {
        self.version = version
        self.name = name
        self.shapes = shapes
        self.texts = texts
        self.importedSVGSource = importedSVGSource
    }

    static func `default`() -> OverlayCardDocument {
        OverlayCardDocument()
    }
}

enum OverlayCardStore {
    private static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CosmicVisualizer", isDirectory: true)
            .appendingPathComponent("overlay_cards.json")
    }

    static func loadOrDefault() -> OverlayCardDocument {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let doc = try? JSONDecoder().decode(OverlayCardDocument.self, from: data)
        else {
            return OverlayCardDocument.default()
        }
        return doc
    }

    static func save(_ doc: OverlayCardDocument) throws {
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(doc)
        try data.write(to: fileURL, options: .atomic)
    }
}
