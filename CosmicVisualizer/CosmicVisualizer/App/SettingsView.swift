import AppKit
import CoreMIDI
import CoreAudio
import SwiftUI

private enum SettingsTransportUITier: String, CaseIterable {
    case basic
    case advanced

    var label: String {
        switch self {
        case .basic: "Basic"
        case .advanced: "Advanced"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @StateObject private var sweepCalibration = DMXSweepCalibrationService()
    @StateObject private var webcam = WebcamCaptureService()
    @AppStorage("settings.transportUITier") private var transportUITierRaw = SettingsTransportUITier.basic.rawValue
    @State private var midiSources: [(uid: Int32, name: String)] = []
    @State private var dmxDevicePaths: [String] = []
    @State private var llmKeyDraft = ""
    @State private var aiPromptDraft = ""
    @State private var obsAudioStatus = ""
    @State private var shareStatus = ""
    @State private var lanIPv4 = ""
    @State private var feedbackTitle = "Beta feedback"
    @State private var feedbackBody = ""

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 14) {
                betaSection
                showProjectSection
                performanceStripsSection
                updatesSection
                feedbackSection
                hybridAISection
                calibrationSection
                audioInputSection
                remoteControlSection
                outputSection
                midiSection
                dmxSection
            }
            .font(.subheadline)
            .frame(maxWidth: 620, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
        .onAppear {
            refreshMIDISources()
            refreshDMXDevices()
            llmKeyDraft = LLMKeychain.loadAPIKey() ?? ""
            refreshLANAddress()
        }
        .onChange(of: appModel.remoteSettings.bindLAN) { _, _ in refreshLANAddress() }
    }
}

private extension SettingsView {
    var betaSection: some View {
        GroupBox("Build") {
            HStack {
                Text(AppBuildInfo.displayVersion)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Re-run setup wizard") {
                    appModel.resetSetupWizard()
                }
                .controlSize(.small)
            }
        }
    }

    var updatesSection: some View {
        GroupBox("App updates") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Updater channel: \(AppBuildInfo.betaLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Check for updates now") {
                    appModel.checkForAppUpdates()
                }
                .controlSize(.small)
                if !appModel.appUpdateStatus.isEmpty {
                    Text(appModel.appUpdateStatus)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var feedbackSection: some View {
        GroupBox("Feedback and error logs") {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Issue title", text: $feedbackTitle)
                    .textFieldStyle(.roundedBorder)
                TextField("Feedback / error details", text: $feedbackBody, axis: .vertical)
                    .lineLimit(3 ... 6)
                    .textFieldStyle(.roundedBorder)
                TextField("GitHub repo (owner/name)", text: stringBinding(\.githubFeedbackRepository))
                    .textFieldStyle(.roundedBorder)
                SecureField("GitHub token (optional)", text: stringBinding(\.githubFeedbackToken))
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Create local feedback bundle") {
                        appModel.createFeedbackBundle(message: feedbackBody)
                    }
                    .controlSize(.small)
                    Button("Submit GitHub issue") {
                        appModel.submitFeedbackIssue(title: feedbackTitle, body: feedbackBody)
                    }
                    .controlSize(.small)
                }
                if !appModel.feedbackStatus.isEmpty {
                    Text(appModel.feedbackStatus)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var showProjectSection: some View {
        GroupBox("Venue / show project") {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Venue name", text: venueNameBinding)
                    .textFieldStyle(.roundedBorder)
                TextField("Show title", text: showTitleBinding)
                    .textFieldStyle(.roundedBorder)
                HStack(spacing: 10) {
                    Button("Save project folder…") {
                        appModel.presentSaveShowProjectPanel()
                    }
                    Button("Open project folder…") {
                        appModel.presentOpenShowProjectPanel()
                    }
                    Button("Export package archive…") {
                        appModel.presentExportShowProjectArchivePanel()
                    }
                    Button("Import package archive…") {
                        appModel.presentImportShowProjectArchivePanel()
                    }
                }
                Text(appModel.currentShowProjectFolder?.path ?? "No project folder — context files go to Application Support.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var venueNameBinding: Binding<String> {
        Binding(
            get: { appModel.showProjectMetadata.venue.name },
            set: { v in
                var m = appModel.showProjectMetadata
                m.venue.name = v
                appModel.showProjectMetadata = m
            }
        )
    }

    var showTitleBinding: Binding<String> {
        Binding(
            get: { appModel.showProjectMetadata.show.title },
            set: { v in
                var m = appModel.showProjectMetadata
                m.show.title = v
                appModel.showProjectMetadata = m
            }
        )
    }

    var performanceStripsSection: some View {
        GroupBox("Live Show strips") {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Lighting cue strip", isOn: boolBinding(\.lightingPerformanceStripEnabled))
                Toggle("Backdrop cue strip", isOn: boolBinding(\.backdropPerformanceStripEnabled))
                Text("When Performance mode is on, strips still appear if enabled here.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var hybridAISection: some View {
        GroupBox("Hybrid AI assistant (optional cloud)") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Enable LLM panel (API key in Keychain)", isOn: boolBinding(\.hybridAIAssistantEnabled))
                Picker("Provider", selection: stringBinding(\.llmProvider)) {
                    Text("OpenAI-compatible").tag("openai")
                    Text("Claude (Anthropic)").tag("anthropic")
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 320, alignment: .leading)
                TextField("Model id", text: stringBinding(\.llmModel))
                    .textFieldStyle(.roundedBorder)
                TextField(
                    AIProviderInfo(providerID: appModel.remoteSettings.llmProvider).defaultBaseURLHint,
                    text: stringBinding(\.llmBaseURL)
                )
                    .textFieldStyle(.roundedBorder)
                SecureField("API key", text: $llmKeyDraft)
                    .textFieldStyle(.roundedBorder)
                Button("Save API key to Keychain") {
                    LLMKeychain.saveAPIKey(llmKeyDraft)
                }
                .disabled(!appModel.remoteSettings.hybridAIAssistantEnabled)
                Divider()
                TextField("Ask the assistant (JSON tool calls)", text: $aiPromptDraft, axis: .vertical)
                    .lineLimit(3 ... 6)
                    .textFieldStyle(.roundedBorder)
                    .disabled(!appModel.remoteSettings.hybridAIAssistantEnabled)
                Button("Send") {
                    let p = aiPromptDraft
                    Task { await appModel.sendHybridAIPrompt(p) }
                }
                .disabled(!appModel.remoteSettings.hybridAIAssistantEnabled || aiPromptDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if !appModel.aiAssistantLastMessage.isEmpty {
                    Text(appModel.aiAssistantLastMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Text("Local tools run without network; LLM is optional. Context files: Application Support or project folder / context.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var calibrationSection: some View {
        GroupBox("Webcam + DMX sweep (calibration)") {
            VStack(alignment: .leading, spacing: 10) {
                Text(
                    "Sweep steps fixture channels while sampling camera brightness. Not for audience-facing shows without shielding; uses low duty cycle by default."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Run sweep to context/calibration.json") {
                        let folder = appModel.currentShowProjectFolder
                            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                            .appendingPathComponent("CosmicVisualizer", isDirectory: true)
                        sweepCalibration.runSweep(model: appModel, webcam: webcam, outputFolder: folder, stepHz: 1)
                    }
                    .disabled(sweepCalibration.isRunning)
                    Button("Cancel") {
                        sweepCalibration.cancel()
                    }
                    .disabled(!sweepCalibration.isRunning)
                }
                if !sweepCalibration.progress.isEmpty {
                    Text(sweepCalibration.progress)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var remoteControlSection: some View {
        GroupBox("Remote control (HTTP + WebSocket)") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Enable server (off by default · use token for LAN)", isOn: boolBinding(\.remoteControlEnabled))
                HStack {
                    Text("Port")
                        .foregroundStyle(.secondary)
                    TextField("8765", value: intBinding(\.remoteControlPort), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                    Toggle("Bind LAN", isOn: boolBinding(\.bindLAN))
                }
                TextField("Auth token (optional)", text: stringBinding(\.authToken))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 420)
                Divider()
                Toggle("Enable OSC UDP control", isOn: boolBinding(\.oscControlEnabled))
                HStack {
                    Text("OSC Port")
                        .foregroundStyle(.secondary)
                    TextField("9000", value: intBinding(\.oscControlPort), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                    Toggle("OSC Bind LAN", isOn: boolBinding(\.oscBindLAN))
                }
                .disabled(!appModel.remoteSettings.oscControlEnabled)
                TextField("OSC token (optional, append token=<value>)", text: stringBinding(\.oscAuthToken))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 420)
                    .disabled(!appModel.remoteSettings.oscControlEnabled)
                if !appModel.oscControlStatus.isEmpty {
                    Text(appModel.oscControlStatus)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text("OSC line examples: /cosmic/scene/next · /cosmic/fractal/zoom f 1.4 · /cosmic/overlay/enabled f 1")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                if let launchURL = remoteLaunchURL {
                    HStack(spacing: 8) {
                        Text(launchURL.absoluteString)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(1)
                        Button("Copy launch link") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(launchURL.absoluteString, forType: .string)
                            shareStatus = "Copied launch link."
                        }
                        .controlSize(.small)
                        ShareLink(
                            item: launchURL,
                            subject: Text("Cosmic Visualizer Web UI"),
                            message: Text("Open this link on the same network to launch the web UI.")
                        ) {
                            Label("AirDrop launch link…", systemImage: "square.and.arrow.up")
                        }
                        .controlSize(.small)
                    }
                    Text("Share link includes the auth token as a query parameter.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else if appModel.remoteSettings.bindLAN {
                    Text("Enable LAN and connect to a network interface with IPv4 to generate a shareable link.")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                if !shareStatus.isEmpty {
                    Text(shareStatus)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text("Open http://127.0.0.1:<port>/ when enabled. Bundle serves WebControl assets.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var audioInputSection: some View {
        GroupBox("Audio input and OBS forwarding") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Input device", selection: appModel.selectedInputDeviceBinding) {
                    Text("System default").tag(Optional<AudioDeviceID>.none)
                    ForEach(appModel.audioEngine.availableInputDevices) { dev in
                        Text(dev.name).tag(Optional<AudioDeviceID>.some(dev.id))
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 460, alignment: .leading)

                Picker("Input channel", selection: appModel.selectedInputChannelBinding) {
                    ForEach(appModel.availableInputChannelChoices) { choice in
                        Text(choice.label).tag(choice)
                    }                    
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 240, alignment: .leading)

                Toggle("Forward audio input to OBS output device", isOn: boolBinding(\.obsAudioForwardEnabled))

                Picker("OBS forwarding output device", selection: stringBinding(\.obsAudioForwardOutputDeviceUID)) {
                    Text("System output").tag("")
                    ForEach(appModel.audioEngine.availableOutputDevices, id: \.uid) { dev in
                        Text(dev.name).tag(dev.uid)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 460, alignment: .leading)
                .disabled(!appModel.remoteSettings.obsAudioForwardEnabled)

                HStack(spacing: 8) {
                    Button("Create OBS aggregate input device") {
                        createOBSAggregateInput()
                    }
                    .controlSize(.small)
                    .disabled(appModel.audioEngine.selectedInputDeviceID == nil)
                    Text("Creates a CoreAudio aggregate input named “Cosmic Visualizer OBS Forward”.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                if !obsAudioStatus.isEmpty {
                    Text(obsAudioStatus)
                        .font(.caption)
                        .foregroundStyle(obsAudioStatus.lowercased().contains("error") ? .red : .secondary)
                }
                if let err = appModel.audioError {
                    HStack(spacing: 8) {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                        if appModel.isMicrophonePermissionDenied {
                            Button("Open Microphone Settings") {
                                appModel.openMicrophonePrivacySettings()
                            }
                            .controlSize(.small)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var outputSection: some View {
        GroupBox("Output and preview") {
            VStack(alignment: .leading, spacing: 10) {
                let screens = ExternalDisplayRouter.screens
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Presentation display")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("Output screen", selection: $appModel.externalOutputScreenIndex) {
                            ForEach(Array(screens.enumerated()), id: \.offset) { pair in
                                Text(ExternalDisplayRouter.displayName(for: pair.element, index: pair.offset))
                                    .tag(pair.offset)
                            }
                        }
                        .labelsHidden()
                        .disabled(screens.isEmpty)
                        HStack(spacing: 12) {
                            Button("Open visualization on display") {
                                appModel.openExternalVisualizationFullscreen()
                            }
                            .disabled(screens.count < 2 || appModel.isExternalVisualizationOpen)
                            if appModel.isExternalVisualizationOpen {
                                Button("Close presentation") {
                                    appModel.closeExternalVisualization()
                                }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview aspect")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("Preview aspect", selection: previewAspectBinding) {
                            ForEach(PreviewAspectRatioSelection.allCases) { mode in
                                Text(mode.pickerLabel).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                        Toggle("Syphon stream for OBS", isOn: boolBinding(\.obsSyphonStreamEnabled))
                        Picker("OBS stream aspect", selection: obsStreamAspectBinding) {
                            ForEach(PreviewAspectRatioSelection.allCases) { mode in
                                Text(mode.pickerLabel).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(!appModel.remoteSettings.obsSyphonStreamEnabled)
                    }
                    .frame(maxWidth: 260, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var midiSection: some View {
        GroupBox("MIDI input") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("MIDI source", selection: midiUIDSelectionBinding) {
                    Text("All MIDI sources").tag("")
                    ForEach(midiSources, id: \.uid) { source in
                        Text("\(source.name) (\(source.uid))").tag(String(source.uid))
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 420, alignment: .leading)
                HStack(spacing: 8) {
                    Button("Refresh MIDI devices") {
                        refreshMIDISources()
                    }
                    .controlSize(.small)
                    TextField("MIDI UID", text: stringBinding(\.midiInputUID))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 220)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var dmxSection: some View {
        GroupBox("DMX & network transport") {
            VStack(alignment: .leading, spacing: 12) {
                transportTierPicker
                Text(transportTierCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                dmxOutputCoreBlock
                if transportUITier == .advanced {
                    dmxOutputDiagnosticsGroup
                }
                Divider()
                dmxInboundCoreBlock
                if transportUITier == .advanced {
                    dmxTransportDiagnosticsGroups
                }
                Divider()
                dmxRDMTieredBlock
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var transportUITier: SettingsTransportUITier {
        SettingsTransportUITier(rawValue: transportUITierRaw) ?? .basic
    }

    private var transportTierCaption: String {
        switch transportUITier {
        case .basic:
            return "Basic: enable transport, pick hardware or network endpoints, and configure inbound merge. Switch to Advanced for live diagnostics, frame timing, and full RDM controls."
        case .advanced:
            return "Advanced: adds streaming status, inbound receiver stats, frame-budget timings, and RDM probe tooling."
        }
    }

    private var transportTierPicker: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("Detail")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Picker("Transport detail level", selection: $transportUITierRaw) {
                ForEach(SettingsTransportUITier.allCases, id: \.rawValue) { tier in
                    Text(tier.label).tag(tier.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)
            Spacer(minLength: 0)
        }
    }

    private var dmxOutputCoreBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DMX output")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Toggle("DMX output enabled", isOn: boolBinding(\.dmxOutputEnabled))
            Picker("DMX output mode", selection: stringBinding(\.dmxOutputMode)) {
                Text("Hardware interface").tag("hardware")
                Text("Simulated interface (offline)").tag("simulated")
                Text("Art-Net (scaffold)").tag("artnet")
                Text("sACN E1.31 (scaffold)").tag("sacn")
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 320, alignment: .leading)
            if appModel.remoteSettings.dmxOutputMode == "simulated" {
                Picker("Simulated adapter", selection: stringBinding(\.dmxSimulatedInterface)) {
                    Text("Enttec Open DMX").tag("enttec_open_dmx")
                    Text("Enttec DMX USB Pro").tag("enttec_usb_pro")
                    Text("Generic USB-DMX").tag("generic_usb_dmx")
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 320, alignment: .leading)
            }
                if appModel.remoteSettings.dmxOutputMode == "artnet" {
                    TextField("Art-Net target host/IP", text: stringBinding(\.dmxArtNetHost))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 320)
                    Stepper(
                        "Network universe offset: \(max(0, appModel.remoteSettings.dmxNetworkUniverse))",
                        value: intBinding(\.dmxNetworkUniverse),
                        in: 0 ... 32767
                    )
                    .frame(maxWidth: 320, alignment: .leading)
                    Text("Each patched fixture universe is sent as its own ArtDMX packet; this value is added to every fixture’s universe index (multi-universe rigs).")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if transportUITier == .advanced {
                        Text("UDP to port 6454; diagnostics show UDP packets per timer tick when output is running.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                if appModel.remoteSettings.dmxOutputMode == "sacn" {
                    TextField("sACN destination host", text: stringBinding(\.dmxSACNHost))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 320)
                    Stepper(
                        "Network universe offset: \(max(0, appModel.remoteSettings.dmxNetworkUniverse))",
                        value: intBinding(\.dmxNetworkUniverse),
                        in: 0 ... 63999
                    )
                    .frame(maxWidth: 320, alignment: .leading)
                    Text("One scaffold E1.31-style frame per logical fixture universe; offset is added to each fixture’s universe index.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if transportUITier == .advanced {
                        Text("Full E1.31 root/data layer and multicast discovery remain roadmap items.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            Picker("Detected DMX USB interfaces", selection: dmxPathSelectionBinding) {
                Text("Select detected interface").tag("")
                ForEach(dmxDevicePaths, id: \.self) { path in
                    Text(path).tag(path)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 420, alignment: .leading)
            .disabled(appModel.remoteSettings.dmxOutputMode != "hardware")
            HStack(spacing: 8) {
                Button("Rescan DMX interfaces") {
                    refreshDMXDevices()
                }
                .controlSize(.small)
                TextField("/dev/cu.usbserial-*", text: stringBinding(\.dmxSerialDevicePath))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 420)
            }
            .disabled(appModel.remoteSettings.dmxOutputMode != "hardware")
        }
    }

    private var dmxOutputDiagnosticsGroup: some View {
        GroupBox {
            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                let d = appModel.dmxOutputDiagnostics()
                HStack(alignment: .top, spacing: 8) {
                    Text("Status")
                        .font(.caption.weight(.semibold))
                    if appModel.remoteSettings.dmxOutputEnabled {
                        Text(d.running ? "Streaming ~\(Int(d.nominalHz)) Hz · \(d.packetsLastTimerTick) UDP pkt/tick" : "Enabled · idle (no frames or device closed)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Output disabled")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let err = d.lastError, !err.isEmpty {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            if appModel.remoteSettings.dmxOutputMode == "simulated",
               let sim = appModel.dmxSimulationSnapshot() {
                Text("Simulation: \(sim.info) · Ch1=\(sim.universe.first ?? 0)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } label: {
            Label("Diagnostics · DMX output stream", systemImage: "arrow.up.circle")
                .font(.caption.weight(.semibold))
        }
    }

    private var dmxInboundCoreBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Inbound DMX merge")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Listener decodes one Art-Net or sACN universe at a time (desk merge into local build). Multi-universe inbound is roadmap.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
            Toggle("Enable inbound DMX merge", isOn: boolBinding(\.dmxInboundEnabled))
            Picker("Inbound mode", selection: stringBinding(\.dmxInboundMode)) {
                Text("Art-Net").tag("artnet")
                Text("sACN").tag("sacn")
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 320, alignment: .leading)
            .disabled(!appModel.remoteSettings.dmxInboundEnabled)
            Stepper(
                "Inbound universe: \(max(0, appModel.remoteSettings.dmxInboundUniverse))",
                value: intBinding(\.dmxInboundUniverse),
                in: 0 ... 63999
            )
            .frame(maxWidth: 320, alignment: .leading)
            .disabled(!appModel.remoteSettings.dmxInboundEnabled)
            Picker("Inbound merge mode", selection: stringBinding(\.dmxInboundMergeMode)) {
                Text("HTP (highest takes precedence)").tag("htp")
                Text("LTP/LPT (latest inbound frame)").tag("lpt")
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 320, alignment: .leading)
            .disabled(!appModel.remoteSettings.dmxInboundEnabled)
        }
    }

    private var dmxTransportDiagnosticsGroups: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupBox {
                TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                    let inbound = appModel.dmxInboundDiagnostics()
                    HStack(alignment: .top, spacing: 8) {
                        Text("Receiver")
                            .font(.caption.weight(.semibold))
                        Text(inbound.running ? "\(inbound.status) · frames: \(inbound.frames)" : inbound.status)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let err = inbound.lastError, !err.isEmpty {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            } label: {
                Label("Diagnostics · Inbound DMX", systemImage: "arrow.down.circle")
                    .font(.caption.weight(.semibold))
            }
            GroupBox {
                TimelineView(.periodic(from: .now, by: 1.0)) { _ in
                    let perf = appModel.dmxPerformanceDiagnostics()
                    HStack(alignment: .top, spacing: 8) {
                        Text("Build / send")
                            .font(.caption.weight(.semibold))
                        Text(
                            "frames: \(perf.frameCount) · avg build: \(String(format: "%.2f", perf.avgBuildMS)) ms · avg send: \(String(format: "%.2f", perf.avgSendMS)) ms · avg total: \(String(format: "%.2f", perf.avgTotalMS)) ms · max: \(String(format: "%.2f", perf.maxTotalMS)) ms · over budget: \(perf.overBudgetFrameCount)"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            } label: {
                Label("Diagnostics · Frame timing", systemImage: "timer")
                    .font(.caption.weight(.semibold))
            }
        }
    }

    private var dmxRDMTieredBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RDM discovery")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Toggle("Enable RDM discovery scaffold", isOn: boolBinding(\.rdmDiscoveryEnabled))
            if transportUITier == .basic {
                if appModel.remoteSettings.rdmDiscoveryEnabled {
                    Text("Advanced detail shows universe, transport, probes, and last results.")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            } else {
                Picker("RDM transport", selection: stringBinding(\.rdmDiscoveryTransportMode)) {
                    Text("Hardware (USB/OpenDMX path)").tag("hardware")
                    Text("Art-Net").tag("artnet")
                    Text("sACN").tag("sacn")
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 320, alignment: .leading)
                .disabled(!appModel.remoteSettings.rdmDiscoveryEnabled)
                Stepper(
                    "RDM universe: \(max(0, appModel.remoteSettings.rdmDiscoveryUniverse))",
                    value: intBinding(\.rdmDiscoveryUniverse),
                    in: 0 ... 63999
                )
                .frame(maxWidth: 320, alignment: .leading)
                .disabled(!appModel.remoteSettings.rdmDiscoveryEnabled)
                Button("Run RDM discovery probe") {
                    appModel.startRDMDiscoveryProbe()
                }
                .disabled(!appModel.remoteSettings.rdmDiscoveryEnabled)
                .controlSize(.small)
                if !appModel.rdmDiscoveryStatus.isEmpty {
                    Text(appModel.rdmDiscoveryStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let result = appModel.rdmDiscoveryResult {
                    Text("Last probe: \(result.mode.uppercased()) universe \(result.universe) · \(result.devices.count) device(s)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    func boolBinding(_ keyPath: WritableKeyPath<RemoteControlSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { appModel.remoteSettings[keyPath: keyPath] },
            set: { value in
                var s = appModel.remoteSettings
                s[keyPath: keyPath] = value
                appModel.remoteSettings = s
            }
        )
    }

    func stringBinding(_ keyPath: WritableKeyPath<RemoteControlSettings, String>) -> Binding<String> {
        Binding(
            get: { appModel.remoteSettings[keyPath: keyPath] },
            set: { value in
                var s = appModel.remoteSettings
                s[keyPath: keyPath] = value
                appModel.remoteSettings = s
            }
        )
    }

    func intBinding(_ keyPath: WritableKeyPath<RemoteControlSettings, Int>) -> Binding<Int> {
        Binding(
            get: { appModel.remoteSettings[keyPath: keyPath] },
            set: { value in
                var s = appModel.remoteSettings
                s[keyPath: keyPath] = value
                appModel.remoteSettings = s
            }
        )
    }

    var previewAspectBinding: Binding<PreviewAspectRatioSelection> {
        Binding(
            get: { appModel.remoteSettings.previewAspectRatioSelection },
            set: { value in
                var s = appModel.remoteSettings
                s.previewAspectRatioSelection = value
                appModel.remoteSettings = s
            }
        )
    }

    var obsStreamAspectBinding: Binding<PreviewAspectRatioSelection> {
        Binding(
            get: { appModel.remoteSettings.obsStreamAspectRatioSelection },
            set: { value in
                var s = appModel.remoteSettings
                s.obsStreamAspectRatioSelection = value
                appModel.remoteSettings = s
            }
        )
    }

    var midiUIDSelectionBinding: Binding<String> {
        Binding(
            get: { appModel.remoteSettings.midiInputUID },
            set: { value in
                var s = appModel.remoteSettings
                s.midiInputUID = value
                appModel.remoteSettings = s
            }
        )
    }

    var dmxPathSelectionBinding: Binding<String> {
        Binding(
            get: { appModel.remoteSettings.dmxSerialDevicePath },
            set: { value in
                var s = appModel.remoteSettings
                s.dmxSerialDevicePath = value
                appModel.remoteSettings = s
            }
        )
    }

    func refreshMIDISources() {
        var next: [(uid: Int32, name: String)] = []
        let sourceCount = MIDIGetNumberOfSources()
        for idx in 0 ..< sourceCount {
            let src = MIDIGetSource(idx)
            var uid: Int32 = 0
            guard MIDIObjectGetIntegerProperty(src, kMIDIPropertyUniqueID, &uid) == noErr else { continue }
            var cfName: Unmanaged<CFString>?
            let status = MIDIObjectGetStringProperty(src, kMIDIPropertyName, &cfName)
            let name = (status == noErr ? (cfName?.takeRetainedValue() as String?) : nil) ?? "MIDI source \(idx)"
            next.append((uid: uid, name: name))
        }
        midiSources = next.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func refreshDMXDevices() {
        let fm = FileManager.default
        let roots = ["/dev"]
        let matchTokens = ["usbserial", "usbmodem", "slab_usb", "wchusb", "ttyusb", "cu.usb"]
        var devices: [String] = []
        for root in roots {
            guard let items = try? fm.contentsOfDirectory(atPath: root) else { continue }
            for item in items {
                let lower = item.lowercased()
                let isTTY = lower.hasPrefix("cu.") || lower.hasPrefix("tty.")
                let likelyDMX = matchTokens.contains(where: { lower.contains($0) })
                if isTTY && likelyDMX {
                    devices.append("\(root)/\(item)")
                }
            }
        }
        dmxDevicePaths = Array(Set(devices)).sorted()
    }

    func createOBSAggregateInput() {
        guard let inputID = appModel.audioEngine.selectedInputDeviceID,
              let input = appModel.audioEngine.availableInputDevices.first(where: { $0.id == inputID })
        else {
            obsAudioStatus = "Select an input device first."
            return
        }
        do {
            let virtualLoopbackUID = appModel.audioEngine.availableOutputDevices.first { dev in
                let lower = dev.name.lowercased()
                return lower.contains("blackhole") || lower.contains("soundflower") || lower.contains("loopback")
            }?.uid
            let aggregateUID = try AudioDeviceEnumerator.createOBSAggregateInputDevice(
                inputDeviceUID: input.uid,
                preferredLoopbackUID: virtualLoopbackUID
            )
            appModel.audioEngine.refreshDevices()
            var s = appModel.remoteSettings
            s.audioInputDeviceUID = aggregateUID
            appModel.remoteSettings = s
            obsAudioStatus = "Created OBS aggregate input device."
        } catch {
            obsAudioStatus = "Error creating OBS aggregate input: \(error.localizedDescription)"
        }
    }

    var remoteLaunchURL: URL? {
        let settings = appModel.remoteSettings
        guard settings.remoteControlEnabled else { return nil }
        let host = settings.bindLAN ? lanIPv4 : "127.0.0.1"
        guard !host.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = settings.remoteControlPort
        components.path = "/"
        let token = settings.authToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !token.isEmpty {
            components.queryItems = [URLQueryItem(name: "token", value: token)]
        }
        return components.url
    }

    func refreshLANAddress() {
        lanIPv4 = localIPv4Address() ?? ""
    }

    func localIPv4Address() -> String? {
        var addr: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let flags = Int32(interface.ifa_flags)
            let isUp = (flags & IFF_UP) == IFF_UP
            let isRunning = (flags & IFF_RUNNING) == IFF_RUNNING
            let isLoopback = (flags & IFF_LOOPBACK) == IFF_LOOPBACK
            guard isUp, isRunning, !isLoopback else { continue }
            guard let sa = interface.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: interface.ifa_name)
            if name.hasPrefix("awdl") || name.hasPrefix("utun") || name.hasPrefix("llw") { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let length = socklen_t(sa.pointee.sa_len)
            let result = getnameinfo(
                sa,
                length,
                &host,
                socklen_t(host.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            if result == 0 {
                addr = String(cString: host)
                if name.hasPrefix("en") { break }
            }
        }
        return addr
    }
}
