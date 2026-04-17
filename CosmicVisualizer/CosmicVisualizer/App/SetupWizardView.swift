import CoreAudio
import SwiftUI

struct SetupWizardView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var stepIndex = 0
    @State private var llmKeyDraft = ""
    @State private var aiProviderStatus = ""

    private let steps: [String] = ["welcome", "project", "audio", "output", "dmx", "ai"]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("Setup wizard · \(AppBuildInfo.displayVersion)")
                    .font(.headline)
                Text("Step \(stepIndex + 1) of \(steps.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                stepContent
                if !appModel.setupWizardDiagnosticsStatus.isEmpty {
                    Text(appModel.setupWizardDiagnosticsStatus)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    if stepIndex > 0 {
                        Button("Back") { stepIndex -= 1 }
                    }
                    Spacer()
                    Button("Skip step") {
                        appModel.markSetupWizardStep(steps[stepIndex], skipped: true)
                        advance()
                    }
                    Button(stepIndex == steps.count - 1 ? "Finish" : "Next") {
                        appModel.markSetupWizardStep(steps[stepIndex], skipped: false)
                        advance()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(20)
            .frame(minWidth: 520, minHeight: 340)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Finish later") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Export diagnostics") {
                        appModel.exportSetupWizardDiagnostics()
                    }
                }
            }
        }
        .onAppear {
            appModel.beginSetupWizardSessionIfNeeded()
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch steps[stepIndex] {
        case "welcome":
            VStack(alignment: .leading, spacing: 8) {
                Text("Welcome to Cosmic Visualizer \(AppBuildInfo.betaLabel).")
                Text("This wizard walks through core setup. Every section is skippable.")
                    .foregroundStyle(.secondary)
            }
        case "project":
            VStack(alignment: .leading, spacing: 8) {
                TextField("Venue name", text: Binding(
                    get: { appModel.showProjectMetadata.venue.name },
                    set: { v in var m = appModel.showProjectMetadata; m.venue.name = v; appModel.showProjectMetadata = m }
                ))
                .textFieldStyle(.roundedBorder)
                TextField("Show title", text: Binding(
                    get: { appModel.showProjectMetadata.show.title },
                    set: { v in var m = appModel.showProjectMetadata; m.show.title = v; appModel.showProjectMetadata = m }
                ))
                .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Save project folder…") { appModel.presentSaveShowProjectPanel() }
                    Button("Open project folder…") { appModel.presentOpenShowProjectPanel() }
                }
            }
        case "audio":
            VStack(alignment: .leading, spacing: 8) {
                Picker("Input device", selection: appModel.selectedInputDeviceBinding) {
                    Text("System default").tag(Optional<AudioDeviceID>.none)
                    ForEach(appModel.audioEngine.availableInputDevices) { dev in
                        Text(dev.name).tag(Optional<AudioDeviceID>.some(dev.id))
                    }
                }
                Picker("Input channel", selection: appModel.selectedInputChannelBinding) {
                    ForEach(appModel.availableInputChannelChoices) { choice in
                        Text(choice.label).tag(choice)
                    }
                }
                Text("Cosmic Visualizer needs microphone access for audio-reactive visuals. If macOS blocks access after a new build/install, use the button below to reopen Privacy settings.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Button("Open Microphone Settings") {
                        appModel.openMicrophonePrivacySettings()
                    }
                    .controlSize(.small)
                    Button("Retry audio start") {
                        appModel.startAudio()
                    }
                    .controlSize(.small)
                }
            }
        case "output":
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Enable remote control", isOn: Binding(
                    get: { appModel.remoteSettings.remoteControlEnabled },
                    set: { v in var s = appModel.remoteSettings; s.remoteControlEnabled = v; appModel.remoteSettings = s }
                ))
                Toggle("Bind LAN", isOn: Binding(
                    get: { appModel.remoteSettings.bindLAN },
                    set: { v in var s = appModel.remoteSettings; s.bindLAN = v; appModel.remoteSettings = s }
                ))
                Toggle("Enable OSC UDP control", isOn: Binding(
                    get: { appModel.remoteSettings.oscControlEnabled },
                    set: { v in var s = appModel.remoteSettings; s.oscControlEnabled = v; appModel.remoteSettings = s }
                ))
                HStack(spacing: 8) {
                    Text("OSC Port")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("9000", value: Binding(
                        get: { appModel.remoteSettings.oscControlPort },
                        set: { v in var s = appModel.remoteSettings; s.oscControlPort = v; appModel.remoteSettings = s }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 120)
                    Toggle("OSC Bind LAN", isOn: Binding(
                        get: { appModel.remoteSettings.oscBindLAN },
                        set: { v in var s = appModel.remoteSettings; s.oscBindLAN = v; appModel.remoteSettings = s }
                    ))
                }
                .disabled(!appModel.remoteSettings.oscControlEnabled)
                Text("OSC helper scripts are available at scripts/osc/ for send/query examples.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Toggle("Enable Syphon stream for OBS", isOn: Binding(
                    get: { appModel.remoteSettings.obsSyphonStreamEnabled },
                    set: { v in var s = appModel.remoteSettings; s.obsSyphonStreamEnabled = v; appModel.remoteSettings = s }
                ))
            }
        case "dmx":
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Enable DMX output", isOn: Binding(
                    get: { appModel.remoteSettings.dmxOutputEnabled },
                    set: { v in var s = appModel.remoteSettings; s.dmxOutputEnabled = v; appModel.remoteSettings = s }
                ))
                Picker("DMX mode", selection: Binding(
                    get: { appModel.remoteSettings.dmxOutputMode },
                    set: { v in var s = appModel.remoteSettings; s.dmxOutputMode = v; appModel.remoteSettings = s }
                )) {
                    Text("Hardware").tag("hardware")
                    Text("Simulated").tag("simulated")
                    Text("Art-Net (scaffold)").tag("artnet")
                    Text("sACN E1.31 (scaffold)").tag("sacn")
                }
            }
        default:
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Enable hybrid AI assistant", isOn: Binding(
                    get: { appModel.remoteSettings.hybridAIAssistantEnabled },
                    set: { v in var s = appModel.remoteSettings; s.hybridAIAssistantEnabled = v; appModel.remoteSettings = s }
                ))
                Picker("Provider", selection: Binding(
                    get: { appModel.remoteSettings.llmProvider },
                    set: { v in var s = appModel.remoteSettings; s.llmProvider = v; appModel.remoteSettings = s }
                )) {
                    Text("OpenAI-compatible").tag("openai")
                    Text("Claude (Anthropic)").tag("anthropic")
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 320, alignment: .leading)
                TextField("Model id", text: Binding(
                    get: { appModel.remoteSettings.llmModel },
                    set: { v in var s = appModel.remoteSettings; s.llmModel = v; appModel.remoteSettings = s }
                ))
                .textFieldStyle(.roundedBorder)
                TextField(
                    selectedAIProvider.defaultBaseURLHint,
                    text: Binding(
                        get: { appModel.remoteSettings.llmBaseURL },
                        set: { v in var s = appModel.remoteSettings; s.llmBaseURL = v; appModel.remoteSettings = s }
                    )
                )
                .textFieldStyle(.roundedBorder)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Selected provider: \(selectedAIProvider.displayName)")
                        .font(.caption.weight(.semibold))
                    Link("API website: \(selectedAIProvider.apiWebsite)", destination: URL(string: selectedAIProvider.apiWebsite)!)
                        .font(.caption2)
                    Button("Copy API URL") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(selectedAIProvider.apiWebsite, forType: .string)
                        aiProviderStatus = "Copied API URL."
                    }
                    .controlSize(.small)
                    Text("Setup checklist:")
                        .font(.caption2.weight(.semibold))
                    ForEach(selectedAIProvider.setupSteps, id: \.self) { step in
                        Text("• \(step)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text("API key is stored in your macOS Keychain.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    if !aiProviderStatus.isEmpty {
                        Text(aiProviderStatus)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                SecureField("API key (optional)", text: $llmKeyDraft)
                    .textFieldStyle(.roundedBorder)
                Button("Save API key to Keychain") {
                    LLMKeychain.saveAPIKey(llmKeyDraft)
                }
            }
        }
    }

    private func advance() {
        if stepIndex >= steps.count - 1 {
            appModel.completeSetupWizard()
            dismiss()
            return
        }
        stepIndex += 1
    }

    private var selectedAIProvider: AIProviderInfo {
        AIProviderInfo(providerID: appModel.remoteSettings.llmProvider)
    }
}
