import Foundation

final class SceneManager: ObservableObject {
    @Published var scenes: [VisualizationScene] = []
    @Published var currentIndex: Int = 0

    func goToNextScene() {
        guard !scenes.isEmpty else { return }
        currentIndex = (currentIndex + 1) % scenes.count
    }

    func goToPreviousScene() {
        guard !scenes.isEmpty else { return }
        currentIndex = (currentIndex - 1 + scenes.count) % scenes.count
    }

    func goToRandomScene() {
        guard scenes.count > 1 else { return }
        var next = Int.random(in: 0..<scenes.count)
        if next == currentIndex { next = (next + 1) % scenes.count }
        currentIndex = next
    }

    func setLiquidLightEnabled(_ enabled: Bool) {
        guard scenes.indices.contains(currentIndex) else { return }
        scenes[currentIndex].liquidLightEnabled = enabled
    }
}
