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
}
