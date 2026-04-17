import AppKit
import CoreAudio
import SwiftUI

struct LiveShowView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 12) {
                if !appModel.performanceMode {
                    Text("Cosmic Visualizer")
                        .font(.largeTitle.bold())
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.95), Color.pink.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }

                if let err = appModel.audioError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                HStack {
                    Spacer()
                    Toggle("Performance", isOn: $appModel.performanceMode)
                        .toggleStyle(.switch)
                }

                devicePicker

                if let renderer = appModel.metalRenderer {
                    AspectFitLivePreviewContainer(renderer: renderer, minHeight: 280)

                    if !appModel.performanceMode {
                        SceneCueStripView()
                            .onAppear {
                                appModel.refreshScenePreviewPool()
                            }
                        tempoStatusRow
                    }
                } else {
                    Text("Metal could not be initialized on this Mac.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 200)
                }

                liveSceneControls
                overlayAndLiquidToggles
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
        .onChange(of: appModel.selectedPaletteID) { _, _ in
            appModel.syncRendererFromScene()
        }
    }

    private var devicePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Audio input")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("Device", selection: appModel.selectedInputDeviceBinding) {
                Text("System default").tag(Optional<AudioDeviceID>.none)
                ForEach(appModel.audioEngine.availableInputDevices) { dev in
                    Text(dev.name).tag(Optional<AudioDeviceID>.some(dev.id))
                }
            }
            .labelsHidden()
        }
    }

    private var liveSceneControls: some View {
        HStack(spacing: 12) {
            Button("Previous") {
                appModel.previousScene()
            }
            .keyboardShortcut(.leftArrow, modifiers: [])

            Button("Next") {
                appModel.nextScene()
            }
            .keyboardShortcut(.rightArrow, modifiers: [])

            Button("Random") {
                appModel.randomScene()
            }

            Button("Fullscreen this window") {
                appModel.toggleMainWindowFullscreen()
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])

            Button("Import overlay…") {
                appModel.importOverlayAsset()
            }
            Button("Remove black → PNG…") {
                appModel.exportBlackBackgroundRemovedCopy()
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(Color(red: 0.45, green: 0.2, blue: 0.75))
    }

    private var overlayAndLiquidToggles: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                Toggle("Logo overlay (GPU + fractal fusion)", isOn: Binding(
                    get: { appModel.overlayEnabled },
                    set: { appModel.applyRemoteCommand(RemoteControlCommand(type: "SetOverlayEnabled", enabled: $0)) }
                ))
                .foregroundStyle(.secondary)
                Toggle("Liquid light", isOn: Binding(
                    get: {
                        guard appModel.sceneManager.scenes.indices.contains(appModel.sceneManager.currentIndex) else { return false }
                        return appModel.sceneManager.scenes[appModel.sceneManager.currentIndex].liquidLightEnabled
                    },
                    set: { on in
                        appModel.applyRemoteCommand(RemoteControlCommand(type: "SetLiquidLightEnabled", enabled: on))
                    }
                ))
            }
            if appModel.overlayEnabled {
                HStack(spacing: 12) {
                    Toggle("Adjust placement (drag / pinch on preview)", isOn: Binding(
                        get: { appModel.overlayPlacementInteractionEnabled },
                        set: { appModel.overlayPlacementInteractionEnabled = $0 }
                    ))
                    Button("Reset logo frame") {
                        appModel.resetOverlayRectToFullFrame()
                    }
                }
            }
        }
        .font(.subheadline)
    }

    private var tempoStatusRow: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("BPM")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(Int(appModel.bpm.rounded()))")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color(red: 0.4, green: 0.95, blue: 0.95))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Beat")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.0f%%", appModel.beatConfidence * 100))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(Color.pink.opacity(0.9))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("MIDI clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(appModel.tempoClock.midiClockRunning ? "Running" : "Idle")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Button("Tap tempo") {
                appModel.applyRemoteCommand(RemoteControlCommand(type: "TapTempo"))
            }
            .buttonStyle(.bordered)
            Text("Full tempo controls live on the Controller tab.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }
}
