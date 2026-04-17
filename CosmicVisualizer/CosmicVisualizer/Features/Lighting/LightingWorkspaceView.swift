import AppKit
import SwiftUI

struct LightingWorkspaceView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var copilotSections = 4
    @State private var copilotStatus = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                patchSection
                cueSection
                modulationSection
                StagePlanView()
                LightingPreview25DView()
                copilotSection
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var patchSection: some View {
        GroupBox("DMX patch") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(
                    "Legacy visualization mapping (channels 1–5)",
                    isOn: Binding(
                        get: { appModel.dmxPatchDocument.useLegacyVisualizationSlots },
                        set: { v in
                            var d = appModel.dmxPatchDocument
                            d.useLegacyVisualizationSlots = v
                            appModel.applyDMXPatchDocument(d)
                        }
                    )
                )
                Text("Mirrors scene index, fractal zoom, liquid turbulence, composite blend, and BPM to the first five channels when enabled.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Add RGB Par fixture") { addRGBParFixture() }
                    Button("Remove last fixture") { removeLastFixture() }
                        .disabled(appModel.dmxPatchDocument.instances.isEmpty)
                }
                List {
                    ForEach(appModel.dmxPatchDocument.instances) { inst in
                        if let profile = appModel.dmxPatchDocument.profile(id: inst.profileID) {
                            HStack {
                                Text(profile.name)
                                Spacer()
                                Text("Start \(inst.startAddress)")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Unknown profile")
                        }
                    }
                }
                .frame(minHeight: 80, maxHeight: 160)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var cueSection: some View {
        GroupBox("Lighting cues") {
            VStack(alignment: .leading, spacing: 8) {
                Picker(
                    "Active cue",
                    selection: Binding<Int?>(
                        get: { appModel.lightingCueDocument.activeCueIndex },
                        set: { appModel.setActiveLightingCueIndex($0) }
                    )
                ) {
                    Text("None").tag(Optional<Int>.none)
                    ForEach(Array(appModel.lightingCueDocument.cues.enumerated()), id: \.offset) { i, cue in
                        Text(cue.name).tag(Optional<Int>.some(i))
                    }
                }
                Text("Fade uses the target cue’s fade time when switching between two cues.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var modulationSection: some View {
        GroupBox("Modulation") {
            VStack(alignment: .leading, spacing: 10) {
                Button("Add sine LFO on channel 10") {
                    var doc = appModel.modulationDocument
                    doc.modulators.append(
                        ModulatorDefinition(
                            name: "Sine test",
                            targetChannel: 10,
                            kind: .lfoSine,
                            depth: 0.35,
                            rateHz: 0.5
                        )
                    )
                    appModel.applyModulationDocument(doc)
                }
                if appModel.modulationDocument.modulators.isEmpty {
                    Text("No modulators. Add one to animate DMX channels.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appModel.modulationDocument.modulators) { m in
                        HStack {
                            Toggle(
                                m.name,
                                isOn: Binding(
                                    get: {
                                        appModel.modulationDocument.modulators.first(where: { $0.id == m.id })?.enabled ?? false
                                    },
                                    set: { on in
                                        var doc = appModel.modulationDocument
                                        guard let i = doc.modulators.firstIndex(where: { $0.id == m.id }) else { return }
                                        doc.modulators[i].enabled = on
                                        appModel.applyModulationDocument(doc)
                                    }
                                )
                            )
                            Spacer()
                            Text("Ch \(m.targetChannel)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var copilotSection: some View {
        GroupBox("Copilot (validated suggestions)") {
            VStack(alignment: .leading, spacing: 10) {
                Stepper("Draft cue sections: \(copilotSections)", value: $copilotSections, in: 1 ... 32)
                HStack {
                    Button("Append draft cues from placeholder structure") {
                        let drafts = appModel.lightingCopilotService.draftCuesFromSongStructurePlaceholder(sectionCount: copilotSections)
                        var doc = appModel.lightingCueDocument
                        doc.cues.append(contentsOf: drafts)
                        appModel.applyLightingCueDocument(doc)
                        copilotStatus = "Appended \(drafts.count) draft cues."
                    }
                    Button("Suggest next RGB Par address") {
                        let rgb = FixtureProfile.builtInRGBPar()
                        let addrs = appModel.lightingCopilotService.suggestNextAddresses(
                            patch: appModel.dmxPatchDocument,
                            profile: rgb,
                            count: 1
                        )
                        copilotStatus = addrs.first.map { "Next gap starts at address \($0)." } ?? "No contiguous span found."
                    }
                }
                if !copilotStatus.isEmpty {
                    Text(copilotStatus)
                        .font(.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func rgbProfileID(in patch: inout DMXPatchDocument) -> UUID {
        let template = FixtureProfile.builtInRGBPar()
        if let p = patch.profiles.first(where: { $0.name == template.name }) {
            return p.id
        }
        patch.profiles.append(template)
        return template.id
    }

    private func addRGBParFixture() {
        var patch = appModel.dmxPatchDocument
        let pid = rgbProfileID(in: &patch)
        guard let profile = patch.profile(id: pid) else { return }
        let addr = appModel.lightingCopilotService.suggestNextAddresses(patch: patch, profile: profile, count: 1).first ?? 6
        let inst = FixtureInstance(profileID: pid, startAddress: addr, manualValues: [
            "0": 200, "1": 220, "2": 40, "3": 180,
        ])
        patch.instances.append(inst)
        appModel.applyDMXPatchDocument(patch)
        var stage = appModel.stageLayoutDocument
        stage.placements[inst.id.uuidString] = StagePlacement(x: 0.5, y: 0.5, rotation: 0)
        appModel.applyStageLayoutDocument(stage)
    }

    private func removeLastFixture() {
        var patch = appModel.dmxPatchDocument
        guard !patch.instances.isEmpty else { return }
        let removed = patch.instances.removeLast()
        appModel.applyDMXPatchDocument(patch)
        var stage = appModel.stageLayoutDocument
        stage.placements.removeValue(forKey: removed.id.uuidString)
        appModel.applyStageLayoutDocument(stage)
    }
}
