import SwiftUI

@main
struct CosmicVisualizerApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appModel)
        }
        .commands {
            CommandMenu("Project") {
                Button("Save Show Project…") {
                    appModel.presentSaveShowProjectPanel()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                Button("Open Show Project…") {
                    appModel.presentOpenShowProjectPanel()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
        }
    }
}
