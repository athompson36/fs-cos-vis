import AppKit
import CoreMIDI
import CoreAudio
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @StateObject private var sweepCalibration = DMXSweepCalibrationService()
    @StateObject private var webcam = WebcamCaptureService()
    @State private var midiSources: [(uid: Int32, name: String)] = []
    @State private var dmxDevicePaths: [String] = []
    @State private var llmKeyDraft = ""
    @State private var aiPromptDraft = ""
    @State private var obsAudioStatus = ""
    @State private var shareStatus = ""
    @State private var lanIPv4 = ""

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 14) {
                showProjectSection
                performanceStripsSection
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
                TextField("Model id", text: stringBinding(\.llmModel))
                    .textFieldStyle(.roundedBorder)
                TextField("Base URL (empty = OpenAI-compatible default)", text: stringBinding(\.llmBaseURL))
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
        GroupBox("DMX output") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("DMX output enabled", isOn: boolBinding(\.dmxOutputEnabled))
                Picker("DMX output mode", selection: stringBinding(\.dmxOutputMode)) {
                    Text("Hardware interface").tag("hardware")
                    Text("Simulated interface (offline)").tag("simulated")
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
                Picker("Detected DMX USB interfaces", selection: dmxPathSelectionBinding) {
                    Text("Select detected interface").tag("")
                    ForEach(dmxDevicePaths, id: \.self) { path in
                        Text(path).tag(path)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 420, alignment: .leading)
                .disabled(appModel.remoteSettings.dmxOutputMode == "simulated")
                HStack(spacing: 8) {
                    Button("Rescan DMX interfaces") {
                        refreshDMXDevices()
                    }
                    .controlSize(.small)
                    TextField("/dev/cu.usbserial-*", text: stringBinding(\.dmxSerialDevicePath))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 420)
                }
                .disabled(appModel.remoteSettings.dmxOutputMode == "simulated")
                TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                    let d = appModel.dmxOutputDiagnostics()
                    HStack(alignment: .top, spacing: 8) {
                        Text("Status")
                            .font(.caption.weight(.semibold))
                        if appModel.remoteSettings.dmxOutputEnabled {
                            Text(d.running ? "Streaming ~\(Int(d.nominalHz)) Hz" : "Enabled · idle (no frames or device closed)")
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
