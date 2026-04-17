import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Minimal vector card authoring: shapes + text; raster composite integration can sample this layer in SwiftUI.
struct OverlayCardAuthoringView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var svgDraft = ""

    var body: some View {
        GroupBox("Overlay cards (vector)") {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Card name", text: cardNameBinding)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Add rectangle") { addRect() }
                    Button("Add text") { addText() }
                    Button("Import SVG as source…") { importSVGSource() }
                }
                if !appModel.overlayCardDocument.shapes.isEmpty || !appModel.overlayCardDocument.texts.isEmpty {
                    List {
                        ForEach(appModel.overlayCardDocument.shapes) { s in
                            Text("Shape \(s.kind.rawValue) \(s.id.uuidString.prefix(6))")
                        }
                        ForEach(appModel.overlayCardDocument.texts) { t in
                            Text("Text: \(t.text.prefix(24))")
                        }
                    }
                    .frame(minHeight: 120, maxHeight: 220)
                }
                Text("SVG / PDF path import stores raw source on the document; render stack integration can rasterize later.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var cardNameBinding: Binding<String> {
        Binding(
            get: { appModel.overlayCardDocument.name },
            set: { v in
                var d = appModel.overlayCardDocument
                d.name = v
                appModel.applyOverlayCardDocument(d)
            }
        )
    }

    private func addRect() {
        var d = appModel.overlayCardDocument
        d.shapes.append(OverlayCardShape(kind: .rect))
        appModel.applyOverlayCardDocument(d)
    }

    private func addText() {
        var d = appModel.overlayCardDocument
        d.texts.append(OverlayCardTextLayer(text: "Title"))
        appModel.applyOverlayCardDocument(d)
    }

    private func importSVGSource() {
        let p = NSOpenPanel()
        p.allowedContentTypes = [.svg, .plainText]
        p.allowsMultipleSelection = false
        guard p.runModal() == .OK, let url = p.url,
              let s = try? String(contentsOf: url, encoding: .utf8)
        else { return }
        var d = appModel.overlayCardDocument
        d.importedSVGSource = s
        d.name = url.deletingPathExtension().lastPathComponent
        appModel.applyOverlayCardDocument(d)
    }
}
