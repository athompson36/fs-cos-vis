import SwiftUI

private enum ControllerMainSection: String, CaseIterable, Identifiable {
    case overview
    case faders

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .faders: "Faders"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "rectangle.split.3x1"
        case .faders: "slider.horizontal.below.rectangle"
        }
    }
}

struct ControllerView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var faderSearchText = ""
    @AppStorage("controller.mainSection") private var controllerSectionRaw = ControllerMainSection.overview.rawValue
    private let sliderHeight: CGFloat = 190

    private var controllerSection: ControllerMainSection {
        ControllerMainSection(rawValue: controllerSectionRaw) ?? .overview
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Controller")
                .font(.title2.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 16)
            controllerSectionBar
            Group {
                switch controllerSection {
                case .overview:
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 16) {
                            statusStrip
                            tempoBlock
                            Divider()
                            mappingSummarySection
                            Divider()
                            mappingLearnSection
                            Divider()
                            dmxOutputLegend
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                    }
                case .faders:
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 14) {
                            faderTabHeader
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(alignment: .top, spacing: 18) {
                                    sceneFadersRegion
                                    if filteredDmxControlGroups.isEmpty, !dmxControlGroups.isEmpty {
                                        ContentUnavailableView(
                                            "No matching fixtures",
                                            systemImage: "line.3.horizontal.decrease.circle",
                                            description: Text("Try a different search, or clear the filter.")
                                        )
                                        .frame(minWidth: 220, minHeight: 120)
                                    } else {
                                        ForEach(filteredDmxControlGroups, id: \.id) { group in
                                            dmxFadersRegion(group)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .cosmicMainTabSurface()
    }

    private var controllerSectionBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Area")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(ControllerMainSection.allCases) { section in
                        controllerSectionChip(section)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 2)
            }
        }
        .padding(.bottom, 8)
    }

    private func controllerSectionChip(_ section: ControllerMainSection) -> some View {
        let selected = controllerSection == section
        return Button {
            controllerSectionRaw = section.rawValue
        } label: {
            Label(section.title, systemImage: section.systemImage)
                .font(.caption.weight(.medium))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    selected ? Color.accentColor.opacity(0.35) : Color.white.opacity(0.06),
                    in: Capsule(style: .continuous)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(selected ? Color.accentColor.opacity(0.55) : Color.white.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var faderTabHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Live faders")
                .font(.headline)
            Text("Scene parameters use the current layer. Fixture sliders send manual DMX values from the patch.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                TextField("Filter fixtures and channels…", text: $faderSearchText)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                if !faderSearchText.isEmpty {
                    Button("Clear") {
                        faderSearchText = ""
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    private var filteredDmxControlGroups: [DMXGroup] {
        let q = faderSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return dmxControlGroups }
        return dmxControlGroups.filter { group in
            if group.title.lowercased().contains(q) { return true }
            return group.controls.contains { $0.label.lowercased().contains(q) }
        }
    }

    private var mappingSummarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Control mappings")
                .font(.headline)
            Text("Saved MIDI routes and how OSC fits alongside them. Faders show assignments under each handle.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    midiContinuousMappingCard
                    midiDiscreteMappingCard
                    oscMappingCard
                }
                VStack(alignment: .leading, spacing: 12) {
                    midiContinuousMappingCard
                    midiDiscreteMappingCard
                    oscMappingCard
                }
            }
        }
    }

    private var midiContinuousMappingCard: some View {
        GroupBox {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    let rows = appModel.midiMapping.continuousCC
                    ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                        let name = LayerControlParameter(parameterID: row.parameterID)?.displayName ?? row.parameterID
                        HStack(alignment: .firstTextBaseline) {
                            Text(name)
                                .font(.caption)
                                .lineLimit(2)
                            Spacer(minLength: 8)
                            Text("Ch \(row.channel + 1) · CC \(row.controller)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        if idx < rows.count - 1 {
                            Divider()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 220)
        } label: {
            Label("MIDI → scene parameters", systemImage: "slider.horizontal.3")
                .font(.subheadline.weight(.semibold))
        }
    }

    private var midiDiscreteMappingCard: some View {
        GroupBox {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    let rows = appModel.midiMapping.cc
                    ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                        HStack(alignment: .firstTextBaseline) {
                            Text(midiTriggerDisplayName(row.commandType))
                                .font(.caption)
                                .lineLimit(2)
                            Spacer(minLength: 8)
                            Text("Ch \(row.channel + 1) · CC \(row.controller)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        if idx < rows.count - 1 {
                            Divider()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 220)
        } label: {
            Label("MIDI → triggers", systemImage: "button.programmable")
                .font(.subheadline.weight(.semibold))
        }
    }

    private var oscMappingCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("OSC uses typed addresses over UDP — the same show actions as the app, without per-control CC learn.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 4) {
                    oscExampleRow("/cosmic/scene/next", "Advance scene")
                    oscExampleRow("/cosmic/tempo/bpm f 128", "Set manual BPM")
                    oscExampleRow("/cosmic/state/get", "Full state JSON (query)")
                }
                Text("Port, bind, and token are in Settings → Remote.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        } label: {
            Label("OSC (network)", systemImage: "network")
                .font(.subheadline.weight(.semibold))
        }
    }

    private func oscExampleRow(_ path: String, _ caption: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(path)
                .font(.caption2.monospaced())
                .foregroundStyle(.primary.opacity(0.9))
                .lineLimit(2)
            Spacer(minLength: 4)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func midiTriggerDisplayName(_ commandType: String) -> String {
        switch commandType {
        case "NextScene": return "Next scene"
        case "PreviousScene": return "Previous scene"
        case "RandomScene": return "Random scene"
        case "TapTempo": return "Tap tempo"
        case "NextLightingCue": return "Next lighting cue"
        case "PreviousLightingCue": return "Previous lighting cue"
        default: return commandType
        }
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
            Text("Hardware learn")
                .font(.headline)
            Text("Choose a layer parameter and MIDI learn, then move a hardware control to assign. DMX learn arrives with incoming desk data.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

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
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                Button(mode.title) {}
                    .buttonStyle(.bordered)
                    .disabled(true)
                Text("Planned")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.18), in: Capsule(style: .continuous))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1)
                    )
            }
            Text(hint)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 240, alignment: .leading)
    }

    private var sceneFadersRegion: some View {
        GroupBox {
            HStack(alignment: .top, spacing: 12) {
                ForEach(LayerControlParameter.allCases) { param in
                    verticalSlider(
                        title: param.displayName,
                        value: appModel.layerFloatBinding(for: param),
                        range: param.floatRange,
                        assignment: .sceneMIDI(line: appModel.midiAssignmentLabel(for: param))
                    )
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Label("Scene parameters", systemImage: "paintpalette")
                    .font(.subheadline.weight(.semibold))
                Text("Layer controls · MIDI assignment under each fader (learn on Overview).")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(8)
        .background(Color.cyan.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    private func dmxFadersRegion(_ group: DMXGroup) -> some View {
        GroupBox {
            HStack(alignment: .top, spacing: 10) {
                ForEach(group.controls) { control in
                    verticalSlider(
                        title: control.label,
                        value: dmxChannelBinding(instanceID: control.instanceID, channelIndex: control.channelIndex),
                        range: 0 ... 255,
                        assignment: .dmxFixtureManual
                    )
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Label(group.title, systemImage: "lightbulb.led.wide")
                    .font(.subheadline.weight(.semibold))
                Text("Fixture manual · stage output (not MIDI learn).")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(8)
        .background(Color.orange.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private enum FaderAssignment {
        case sceneMIDI(line: String?)
        case dmxFixtureManual
    }

    @ViewBuilder
    private func assignmentHeader(_ assignment: FaderAssignment) -> some View {
        switch assignment {
        case .sceneMIDI(let line):
            VStack(spacing: 2) {
                Text("MIDI")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.cyan.opacity(0.95))
                if let line {
                    Text(line)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                } else {
                    Text("Unassigned")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        case .dmxFixtureManual:
            VStack(spacing: 2) {
                Text("DMX")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.orange.opacity(0.95))
                Text("Manual out")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func verticalSlider(
        title: String,
        value: Binding<Float>,
        range: ClosedRange<Float>,
        assignment: FaderAssignment
    ) -> some View {
        let captionHeight: CGFloat = 34
        return VStack(spacing: 6) {
            assignmentHeader(assignment)
                .frame(height: captionHeight)
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
        .frame(width: 84, height: sliderHeight + 70 + captionHeight - 12, alignment: .top)
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
