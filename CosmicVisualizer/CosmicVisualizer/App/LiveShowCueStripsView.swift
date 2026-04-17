import SwiftUI

/// Live Show: optional lighting + backdrop cue strips with bookmarks drawer.
struct LiveShowCueStripsView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var bookmarksExpanded = false
    var chipScale: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if appModel.remoteSettings.lightingPerformanceStripEnabled {
                stripHeader(title: "Lighting cues")
                lightingBookmarkChips
                lightingStrip
            }
            if appModel.remoteSettings.backdropPerformanceStripEnabled {
                stripHeader(title: "Backdrop cues")
                backdropBookmarkChips
                backdropStrip
            }
            if appModel.remoteSettings.lightingPerformanceStripEnabled || appModel.remoteSettings.backdropPerformanceStripEnabled {
                DisclosureGroup(isExpanded: $bookmarksExpanded) {
                    bookmarkLists
                } label: {
                    Text("Bookmarks & jumps")
                        .font(.caption.weight(.semibold))
                }
            }
        }
    }

    private func stripHeader(title: String) -> some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var lightingStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(appModel.lightingCueDocument.cues.enumerated()), id: \.element.id) { pair in
                    cueChip(
                        label: pair.element.name,
                        active: appModel.lightingCueDocument.activeCueIndex == pair.offset
                    ) {
                        appModel.setActiveLightingCueIndex(pair.offset)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var backdropStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(appModel.backdropCueDocument.cues.enumerated()), id: \.element.id) { pair in
                    cueChip(
                        label: pair.element.name,
                        active: appModel.backdropCueDocument.activeCueIndex == pair.offset
                    ) {
                        appModel.applyBackdropCueIndex(pair.offset)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func cueChip(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12 * chipScale))
                .lineLimit(1)
                .padding(.horizontal, 10 * chipScale)
                .padding(.vertical, 6 * chipScale)
                .background(active ? Color.accentColor.opacity(0.35) : Color.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var lightingBookmarkChips: some View {
        let ids = appModel.lightingCueDocument.bookmarkedCueIds
        let cues = appModel.lightingCueDocument.cues
        let entries: [(UUID, Int, String)] = ids.compactMap { bid in
            guard let idx = cues.firstIndex(where: { $0.id == bid }) else { return nil }
            return (bid, idx, cues[idx].name)
        }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(entries, id: \.0) { entry in
                    Button(entry.2) {
                        appModel.setActiveLightingCueIndex(entry.1)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    private var backdropBookmarkChips: some View {
        let ids = appModel.backdropCueDocument.bookmarkedCueIds
        let cues = appModel.backdropCueDocument.cues
        let entries: [(UUID, Int, String)] = ids.compactMap { bid in
            guard let idx = cues.firstIndex(where: { $0.id == bid }) else { return nil }
            return (bid, idx, cues[idx].name)
        }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(entries, id: \.0) { entry in
                    Button(entry.2) {
                        appModel.applyBackdropCueIndex(entry.1)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    private var bookmarkLists: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lighting bookmarks")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            ForEach(appModel.lightingCueDocument.bookmarkedCueIds, id: \.self) { id in
                if let idx = appModel.lightingCueDocument.cues.firstIndex(where: { $0.id == id }) {
                    HStack {
                        Text(appModel.lightingCueDocument.cues[idx].name)
                        Spacer()
                        Button("Go") { appModel.setActiveLightingCueIndex(idx) }
                            .controlSize(.small)
                    }
                }
            }
            Divider()
            Text("Backdrop bookmarks")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            ForEach(appModel.backdropCueDocument.bookmarkedCueIds, id: \.self) { id in
                if let idx = appModel.backdropCueDocument.cues.firstIndex(where: { $0.id == id }) {
                    HStack {
                        Text(appModel.backdropCueDocument.cues[idx].name)
                        Spacer()
                        Button("Go") { appModel.applyBackdropCueIndex(idx) }
                            .controlSize(.small)
                    }
                }
            }
        }
        .font(.caption)
    }
}
