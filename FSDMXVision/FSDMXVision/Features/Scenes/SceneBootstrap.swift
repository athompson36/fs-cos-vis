import Foundation

enum SceneBootstrap {
    static let starterScenes: [VisualizationScene] = [
        VisualizationScene(name: "Julia Bloom", fractalMode: "julia", liquidLightEnabled: true),
        VisualizationScene(name: "Mandel Tunnel", fractalMode: "mandelbrot", liquidLightEnabled: true),
        VisualizationScene(name: "Fractal Focus", fractalMode: "julia", liquidLightEnabled: false),
        VisualizationScene(name: "Liquid Only", fractalMode: "julia", liquidLightEnabled: true),
    ]
}
