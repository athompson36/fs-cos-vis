import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        TabView {
            LiveShowView()
                .tabItem { Label("Live Show", systemImage: "sparkles.tv") }

            SceneStudioView()
                .tabItem { Label("Scene Studio", systemImage: "square.stack.3d.up.fill") }

            ControllerView()
                .tabItem { Label("Controller", systemImage: "slider.horizontal.3") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }

            LightingWorkspaceView()
                .tabItem { Label("Lighting", systemImage: "light.beacon.max.fill") }
        }
        .cosmicShellBackground()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { appModel.startAudio() }
        .onDisappear { appModel.stopAudio() }
    }
}
