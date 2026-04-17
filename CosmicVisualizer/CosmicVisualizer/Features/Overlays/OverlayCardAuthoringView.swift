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
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Shape \(s.kind.rawValue) \(s.id.uuidString.prefix(6))")
                                    .font(.caption.weight(.semibold))
                                HStack {
                                    Toggle("Timeout", isOn: shapeTimeoutEnabledBinding(shapeID: s.id))
                                        .toggleStyle(.switch)
                                        .controlSize(.small)
                                    TextField("Seconds", value: shapeTimeoutSecondsBinding(shapeID: s.id), format: .number)
                                        .frame(width: 72)
                                        .textFieldStyle(.roundedBorder)
                                        .disabled(!shapeTimeoutEnabledBinding(shapeID: s.id).wrappedValue)
                                }
                            }
                        }
                        ForEach(appModel.overlayCardDocument.texts) { t in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Text: \(t.text.prefix(24))")
                                    .font(.caption.weight(.semibold))
                                TextField("Metadata key (optional)", text: textMetadataKeyBinding(textID: t.id))
                                    .textFieldStyle(.roundedBorder)
                                HStack {
                                    Toggle("Timeout", isOn: textTimeoutEnabledBinding(textID: t.id))
                                        .toggleStyle(.switch)
                                        .controlSize(.small)
                                    TextField("Seconds", value: textTimeoutSecondsBinding(textID: t.id), format: .number)
                                        .frame(width: 72)
                                        .textFieldStyle(.roundedBorder)
                                        .disabled(!textTimeoutEnabledBinding(textID: t.id).wrappedValue)
                                }
                            }
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

    private func shapeTimeoutEnabledBinding(shapeID: UUID) -> Binding<Bool> {
        Binding(
            get: {
                appModel.overlayCardDocument.shapes.first(where: { $0.id == shapeID })?.timeoutSeconds != nil
            },
            set: { isEnabled in
                var d = appModel.overlayCardDocument
                guard let idx = d.shapes.firstIndex(where: { $0.id == shapeID }) else { return }
                d.shapes[idx].timeoutSeconds = isEnabled ? max(1, d.shapes[idx].timeoutSeconds ?? 5) : nil
                appModel.applyOverlayCardDocument(d)
            }
        )
    }

    private func shapeTimeoutSecondsBinding(shapeID: UUID) -> Binding<Double> {
        Binding(
            get: {
                appModel.overlayCardDocument.shapes.first(where: { $0.id == shapeID })?.timeoutSeconds ?? 5
            },
            set: { seconds in
                var d = appModel.overlayCardDocument
                guard let idx = d.shapes.firstIndex(where: { $0.id == shapeID }) else { return }
                d.shapes[idx].timeoutSeconds = max(0.1, seconds)
                appModel.applyOverlayCardDocument(d)
            }
        )
    }

    private func textMetadataKeyBinding(textID: UUID) -> Binding<String> {
        Binding(
            get: {
                appModel.overlayCardDocument.texts.first(where: { $0.id == textID })?.metadataKey ?? ""
            },
            set: { key in
                var d = appModel.overlayCardDocument
                guard let idx = d.texts.firstIndex(where: { $0.id == textID }) else { return }
                let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
                d.texts[idx].metadataKey = trimmed.isEmpty ? nil : trimmed
                appModel.applyOverlayCardDocument(d)
            }
        )
    }

    private func textTimeoutEnabledBinding(textID: UUID) -> Binding<Bool> {
        Binding(
            get: {
                appModel.overlayCardDocument.texts.first(where: { $0.id == textID })?.timeoutSeconds != nil
            },
            set: { isEnabled in
                var d = appModel.overlayCardDocument
                guard let idx = d.texts.firstIndex(where: { $0.id == textID }) else { return }
                d.texts[idx].timeoutSeconds = isEnabled ? max(1, d.texts[idx].timeoutSeconds ?? 5) : nil
                appModel.applyOverlayCardDocument(d)
            }
        )
    }

    private func textTimeoutSecondsBinding(textID: UUID) -> Binding<Double> {
        Binding(
            get: {
                appModel.overlayCardDocument.texts.first(where: { $0.id == textID })?.timeoutSeconds ?? 5
            },
            set: { seconds in
                var d = appModel.overlayCardDocument
                guard let idx = d.texts.firstIndex(where: { $0.id == textID }) else { return }
                d.texts[idx].timeoutSeconds = max(0.1, seconds)
                appModel.applyOverlayCardDocument(d)
            }
        )
    }
}
