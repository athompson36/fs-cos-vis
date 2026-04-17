import SwiftUI

/// Horizontal cue cards with live Metal previews — main window only (not used on external projection).
struct SceneCueStripView: View {
    @EnvironmentObject private var appModel: AppModel
    var cardScale: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scene cue")
                .font(.caption)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(Array(appModel.sceneManager.scenes.enumerated()), id: \.element.id) { index, scene in
                        let isLive = index == appModel.sceneManager.currentIndex
                        if let renderer = appModel.scenePreviewRenderers[scene.id] {
                            SceneCueCard(
                                scene: scene,
                                isLive: isLive,
                                renderer: renderer,
                                cardScale: cardScale
                            )
                        } else {
                            SceneCueCardPlaceholder(scene: scene, isLive: isLive, cardScale: cardScale)
                        }
                    }
                }
            }
        }
    }
}

private struct SceneCueCard: View {
    @EnvironmentObject private var appModel: AppModel
    let scene: VisualizationScene
    let isLive: Bool
    @ObservedObject var renderer: CompositeRenderer
    let cardScale: CGFloat

    var body: some View {
        let w = 156 * cardScale
        let h = 88 * cardScale
        Button {
            appModel.applyRemoteCommand(RemoteControlCommand(type: "JumpToScene", sceneID: scene.id))
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                VisualizationMetalView(renderer: renderer, preferredFramesPerSecond: 30)
                    .frame(width: w, height: h)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(isLive ? Color.cyan : Color.white.opacity(0.15), lineWidth: isLive ? 2.5 : 1)
                    )
                Text(scene.name)
                    .font(.caption2)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(width: w, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Cue scene: \(scene.name)")
    }
}

private struct SceneCueCardPlaceholder: View {
    let scene: VisualizationScene
    let isLive: Bool
    let cardScale: CGFloat

    var body: some View {
        let w = 156 * cardScale
        let h = 88 * cardScale
        VStack(alignment: .leading, spacing: 4) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .frame(width: w, height: h)
                .overlay {
                    ProgressView()
                        .scaleEffect(0.7 * cardScale)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(isLive ? Color.cyan : Color.white.opacity(0.12), lineWidth: isLive ? 2.5 : 1)
                )
            Text(scene.name)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(width: w, alignment: .leading)
        }
    }
}
