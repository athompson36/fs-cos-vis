import SwiftUI

struct ControllerView: View {
    @EnvironmentObject private var appModel: AppModel
    private let sliderHeight: CGFloat = 190

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Controller")
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)

                statusStrip

                tempoBlock

                Divider()

                mappingLearnSection

                Divider()

                Text("Active controls")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 18) {
                        sceneControlGroup
                        ForEach(dmxControlGroups, id: \.id) { group in
                            dmxControlGroup(group)
                        }
                    }
                }

                Divider()

                dmxOutputLegend
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }

    private var statusStrip: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("BPM")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(String(format: "%.1f", appModel.bpm))
                    .font(.title3.monospacedDigit())
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Beat conf.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(String(format: "%.0f%%", appModel.beatConfidence * 100))
                    .font(.body.monospacedDigit())
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("MIDI clock")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(appModel.tempoClock.midiClockRunning ? "Running" : "Idle")
                    .font(.caption)
            }
            Spacer()
        }
    }

    private var tempoBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tempo")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Source")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Picker("Source", selection: Binding(
                        get: { appModel.tempoClock.syncSource },
                        set: { appModel.applyRemoteCommand(RemoteControlCommand(type: "SetTempoSource", source: $0.rawValue)) }
                    )) {
                        Text("Audio detect").tag(TempoClockService.SyncSource.audioDetection)
                        Text("Manual").tag(TempoClockService.SyncSource.manual)
                        Text("Tap").tag(TempoClockService.SyncSource.tapTempo)
                        Text("MIDI clock").tag(TempoClockService.SyncSource.midiClock)
                    }
                    .labelsHidden()
                    .frame(maxWidth: 300)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Manual BPM")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    TextField("120", value: Binding(
                        get: { appModel.tempoClock.manualBPM },
                        set: { appModel.applyRemoteCommand(RemoteControlCommand(type: "SetManualBPM", bpm: $0)) }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 100)
                }
                Button("Tap tempo") {
                    appModel.applyRemoteCommand(RemoteControlCommand(type: "TapTempo"))
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            }
        }
    }

    private var mappingLearnSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Auto-detect mapping")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Pick a layer parameter, choose MIDI (or Coming soon: DMX / combined), then move a hardware control to assign.")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Picker("Learn target", selection: $appModel.midiLearnTarget) {
                Text("None").tag(Optional<LayerControlParameter>.none)
                ForEach(LayerControlParameter.allCases) { p in
                    Text(p.displayName).tag(Optional(p))
                }
            }
            .frame(maxWidth: 400)

            HStack(spacing: 10) {
                learnModeButton(.off)
                learnModeButton(.midi)
                learnModeButtonDisabled(.dmx, hint: "Requires incoming DMX (Art-Net / sACN — planned).")
                learnModeButtonDisabled(.both, hint: "DMX leg pending; MIDI learn works today when “MIDI” is selected.")
            }
            if appModel.controlLearnMode == .midi, appModel.midiLearnTarget == nil {
                Text("Select a parameter in “Learn target” before moving a control.")
                    .font(.caption)
                    .foregroundStyle(Color.orange.opacity(0.95))
            } else if appModel.controlLearnMode == .midi, appModel.midiLearnTarget != nil {
                Text("Listening for MIDI CC… move a fader or knob.")
                    .font(.caption)
                    .foregroundStyle(Color.orange.opacity(0.95))
            }
        }
    }

    private func learnModeButton(_ mode: ControlLearnMode) -> some View {
        Button {
            appModel.controlLearnMode = mode
            if mode == .off {
                appModel.midiLearnTarget = nil
            }
        } label: {
            Text(mode.title)
                .frame(minWidth: 72)
        }
        .buttonStyle(.bordered)
        .tint(appModel.controlLearnMode == mode ? Color.accentColor : Color.secondary.opacity(0.4))
    }

    private func learnModeButtonDisabled(_ mode: ControlLearnMode, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Button(mode.title) {}
                .buttonStyle(.bordered)
                .disabled(true)
            Text(hint)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 220, alignment: .leading)
    }

    private var sceneControlGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Backdrop scene")
                .font(.caption.weight(.semibold))
            HStack(alignment: .top, spacing: 12) {
                ForEach(LayerControlParameter.allCases) { param in
                    verticalSlider(
                        title: param.displayName,
                        value: appModel.layerFloatBinding(for: param),
                        range: param.floatRange,
                        assignmentLabel: appModel.midiAssignmentLabel(for: param)
                    )
                }
            }
        }
    }

    private struct DMXGroup: Identifiable {
        var id: UUID
        var title: String
        var controls: [DMXControl]
    }

    private struct DMXControl: Identifiable {
        var id: String
        var instanceID: UUID
        var channelIndex: Int
        var label: String
    }

    private var dmxControlGroups: [DMXGroup] {
        appModel.dmxPatchDocument.instances.compactMap { instance in
            guard let profile = appModel.dmxPatchDocument.profile(id: instance.profileID) else { return nil }
            let title = "\(profile.name) @ \(instance.startAddress)"
            let controls = profile.channels.enumerated().map { pair in
                DMXControl(
                    id: "\(instance.id)-\(pair.offset)",
                    instanceID: instance.id,
                    channelIndex: pair.offset,
                    label: pair.element.label
                )
            }
            return DMXGroup(id: instance.id, title: title, controls: controls)
        }
    }

    private func dmxControlGroup(_ group: DMXGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.title)
                .font(.caption.weight(.semibold))
            HStack(alignment: .top, spacing: 10) {
                ForEach(group.controls) { control in
                    verticalSlider(
                        title: control.label,
                        value: dmxChannelBinding(instanceID: control.instanceID, channelIndex: control.channelIndex),
                        range: 0 ... 255,
                        assignmentLabel: "DMX"
                    )
                }
            }
        }
    }

    private func verticalSlider(
        title: String,
        value: Binding<Float>,
        range: ClosedRange<Float>,
        assignmentLabel: String?
    ) -> some View {
        VStack(spacing: 6) {
            if let assignmentLabel {
                Text(assignmentLabel)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
            } else {
                Spacer().frame(height: 0)
            }
            Slider(value: value, in: range)
                .rotationEffect(.degrees(-90))
                .frame(width: sliderHeight, height: 28)
                .fixedSize()
            Text(title)
                .font(.caption2)
                .multilineTextAlignment(.center)
                .frame(width: 80)
                .lineLimit(2)
        }
        .frame(width: 84, height: sliderHeight + 70, alignment: .top)
    }

    private func dmxChannelBinding(instanceID: UUID, channelIndex: Int) -> Binding<Float> {
        Binding(
            get: {
                guard let instance = appModel.dmxPatchDocument.instances.first(where: { $0.id == instanceID }) else { return 0 }
                return Float(instance.manual(forChannelIndex: channelIndex))
            },
            set: { value in
                var doc = appModel.dmxPatchDocument
                guard let idx = doc.instances.firstIndex(where: { $0.id == instanceID }) else { return }
                doc.instances[idx].setManual(channelIndex: channelIndex, value: UInt8(max(0, min(255, Int(value.rounded())))))
                appModel.applyDMXPatchDocument(doc)
            }
        )
    }

    private var dmxOutputLegend: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DMX output mapping (transmit)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(
                """
                Universe slots used when DMX output is enabled (1-based channel numbers): \
                1 → scene index; 2 → fractal zoom (scaled); 3 → liquid turbulence (scaled); \
                4 → composite blend; 5 → BPM (0–255). Incoming DMX learn is not available yet.
                """
            )
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}
