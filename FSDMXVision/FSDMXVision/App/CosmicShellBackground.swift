import SwiftUI

extension View {
    func cosmicShellBackground() -> some View {
        background(
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.02, blue: 0.12),
                    Color(red: 0.08, green: 0.03, blue: 0.18),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    /// Consistent “liquid glass” panel for each root tab (matches material chrome across Live Show, Studio, Controller, Settings, Lighting).
    func cosmicMainTabSurface() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            )
            .padding(12)
    }
}
