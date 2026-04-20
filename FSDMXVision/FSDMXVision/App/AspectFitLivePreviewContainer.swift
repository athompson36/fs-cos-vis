import AppKit
import SwiftUI

/// Letterboxes `LivePreviewWithOverlayInteraction` to `AppModel.resolvedPreviewAspectRatio()`.
struct AspectFitLivePreviewContainer: View {
    @EnvironmentObject private var appModel: AppModel
    let renderer: CompositeRenderer
    var minHeight: CGFloat = 200

    @State private var layoutEpoch = 0

    var body: some View {
        GeometryReader { geo in
            let ar = appModel.resolvedPreviewAspectRatio()
            let fit = PreviewAspectRatioSelection.aspectFitSize(container: geo.size, aspect: ar)
            LivePreviewWithOverlayInteraction(renderer: renderer, minPreviewHeight: 1)
                .frame(width: fit.width, height: fit.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(minHeight: minHeight)
        .id("\(layoutEpoch)-\(appModel.remoteSettings.previewAspectRatioSelection.rawValue)-\(appModel.externalOutputScreenIndex)")
        .onChange(of: appModel.remoteSettings.previewAspectRatioSelection) { _, _ in
            layoutEpoch &+= 1
        }
        .onChange(of: appModel.externalOutputScreenIndex) { _, _ in
            layoutEpoch &+= 1
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResizeNotification)) { _ in
            guard appModel.remoteSettings.previewAspectRatioSelection == .applicationWindow else { return }
            layoutEpoch &+= 1
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            layoutEpoch &+= 1
        }
    }
}
