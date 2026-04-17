import SwiftUI

/// Live readout of the first N channels of universe 0 (matches USB output build path).
struct DMXUniverseMonitorView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var modSmoothed: [UUID: Float] = [:]
    @State private var universe: [UInt8] = Array(repeating: 0, count: 512)

    private let channelCount: Int

    init(channelCount: Int = 32) {
        self.channelCount = min(512, max(8, channelCount))
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { context in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(0 ..< channelCount, id: \.self) { idx in
                        channelCell(dmxChannel: idx + 1, value: universe.indices.contains(idx) ? universe[idx] : 0)
                    }
                }
            }
            .onChange(of: context.date) { _, _ in
                tickUniverse()
            }
            .onAppear {
                tickUniverse()
            }
        }
    }

    private func tickUniverse() {
        var s = modSmoothed
        universe = appModel.buildDMXUniverse(time: CFAbsoluteTimeGetCurrent(), lastSmoothed: &s)
        modSmoothed = s
    }

    private func channelCell(dmxChannel: Int, value: UInt8) -> some View {
        VStack(spacing: 1) {
            Text("\(dmxChannel)")
                .font(.system(size: 7, design: .monospaced))
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.system(size: 10, design: .monospaced).weight(.medium))
        }
        .frame(minWidth: 28)
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
