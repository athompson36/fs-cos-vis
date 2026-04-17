import CoreMIDI
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var midiSources: [(uid: Int32, name: String)] = []
    @State private var dmxDevicePaths: [String] = []

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 14) {
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
        }
    }
}

private extension SettingsView {
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
                Text("Open http://127.0.0.1:<port>/ when enabled. Bundle serves WebControl assets.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
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
                Picker("Detected DMX USB interfaces", selection: dmxPathSelectionBinding) {
                    Text("Select detected interface").tag("")
                    ForEach(dmxDevicePaths, id: \.self) { path in
                        Text(path).tag(path)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 420, alignment: .leading)
                HStack(spacing: 8) {
                    Button("Rescan DMX interfaces") {
                        refreshDMXDevices()
                    }
                    .controlSize(.small)
                    TextField("/dev/cu.usbserial-*", text: stringBinding(\.dmxSerialDevicePath))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 420)
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
}
