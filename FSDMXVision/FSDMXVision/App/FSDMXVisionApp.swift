import SwiftUI

@main
struct FSDMXVisionApp: App {
    @StateObject private var appModel: AppModel

    init() {
        LegacyInstallMigration.runIfNeeded()
        _appModel = StateObject(wrappedValue: AppModel())
    }

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
