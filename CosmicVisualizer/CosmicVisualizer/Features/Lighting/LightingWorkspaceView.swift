import AppKit
import AVFoundation
import SwiftUI

struct LightingWorkspaceView: View {
    @EnvironmentObject private var appModel: AppModel
    @StateObject private var fogLearnWebcam = WebcamCaptureService()
    @StateObject private var fixtureVerifyWebcam = WebcamCaptureService()
    @StateObject private var fixtureVerifySecondaryWebcam = WebcamCaptureService()
    @State private var fogLearnCueID: UUID?
    @State private var fogLearnHazerID: UUID?
    @State private var copilotSections = 4
    @State private var copilotStatus = ""
    @State private var selectedCueID: UUID?
    @State private var selectedProfileID: UUID?
    @State private var cueTransportJSON = ""
    @State private var profileTransportJSON = ""
    @State private var modulationTransportJSON = ""
    @State private var patchTransportJSON = ""
    @State private var stageTransportJSON = ""
    @State private var lightingBundleJSON = ""
    @State private var oflManufacturer = "cameo"
    @State private var oflFixtureSlug = "root-par"
    @State private var oflStatus = ""
    @State private var oflCatalog: [OFLFixtureImportService.CatalogEntry] = []
    @State private var selectedCatalogFixtureID: String?
    @State private var fixtureVerifyAvailableCameras: [AVCaptureDevice] = []
    @State private var fixtureVerifyPrimaryCameraID: String?
    @State private var fixtureVerifyUseSecondaryCamera = false
    @State private var fixtureVerifySecondaryCameraID: String?

    var body: some View {
        TabView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    patchSection
                    oflImportSection
                    cueSection
                    backdropCueSection
                    StagePlanView()
                    LightingPreview25DView()
                }
                .padding()
            }
            .tabItem { Text("Patch & stage") }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    modulationSection
                    jsonTransportSection
                    copilotSection
                }
                .padding()
            }
            .tabItem { Text("Modulation & tools") }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var oflImportSection: some View {
        GroupBox("Open Fixture Library (download)") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("Manufacturer", text: $oflManufacturer)
                        .textFieldStyle(.roundedBorder)
                    TextField("Fixture slug", text: $oflFixtureSlug)
                        .textFieldStyle(.roundedBorder)
                    Button("Fetch & add profile") {
                        Task { await importOFLProfile() }
                    }
                }
                Text(oflStatus)
                    .font(.caption)
                    .foregroundStyle(oflStatus.contains("fail") || oflStatus.contains("error") ? .red : .secondary)
                Divider()
                HStack {
                    Button("Sync curated OFL catalog") {
                        Task { await syncCuratedOFLCatalog() }
                    }
                    .controlSize(.small)
                    if !oflCatalog.isEmpty {
                        Text("\(oflCatalog.count) curated fixtures cached")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                if !oflCatalog.isEmpty {
                    Picker("Curated fixtures", selection: $selectedCatalogFixtureID) {
                        Text("Select…").tag(Optional<String>.none)
                        ForEach(oflCatalog, id: \.id) { entry in
                            Text("\(entry.manufacturerName) · \(entry.fixtureName)\(entry.isFogRelated ? " · Fog/Haze" : "")")
                                .tag(Optional(entry.id))
                        }
                    }
                    .pickerStyle(.menu)
                    HStack {
                        Button("Import selected curated fixture") {
                            Task { await importSelectedCuratedFixture() }
                        }
                        .disabled(selectedCatalogFixtureID == nil)
                    }
                    .controlSize(.small)
                }
            }
        }
        .onAppear {
            if oflCatalog.isEmpty, let cached = OFLFixtureImportService.loadCuratedCatalog() {
                oflCatalog = cached.entries
            }
        }
    }

    private var backdropCueSection: some View {
        GroupBox("Backdrop cues") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Snapshots of the current stage layout (and backdrop path) for Live Show.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Save current layout as backdrop cue") {
                        var d = appModel.backdropCueDocument
                        let name = "Backdrop \(d.cues.count + 1)"
                        let cue = BackdropCue(
                            name: name,
                            layoutSnapshot: appModel.stageLayoutDocument,
                            backdropImagePath: appModel.stageLayoutDocument.backdropAssetPath
                        )
                        d.cues.append(cue)
                        appModel.applyBackdropCueDocument(d)
                    }
                    Button("Clear active backdrop cue") {
                        appModel.setActiveBackdropCueIndex(nil)
                    }
                }
                if appModel.backdropCueDocument.cues.isEmpty {
                    Text("No backdrop cues yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(appModel.backdropCueDocument.cues.enumerated()), id: \.element.id) { pair in
                        HStack {
                            Text(pair.element.name)
                            Toggle(
                                "★",
                                isOn: Binding(
                                    get: { appModel.backdropCueDocument.bookmarkedCueIds.contains(pair.element.id) },
                                    set: { on in
                                        var d = appModel.backdropCueDocument
                                        if on {
                                            if !d.bookmarkedCueIds.contains(pair.element.id) {
                                                d.bookmarkedCueIds.append(pair.element.id)
                                            }
                                        } else {
                                            d.bookmarkedCueIds.removeAll { $0 == pair.element.id }
                                        }
                                        appModel.applyBackdropCueDocument(d)
                                    }
                                )
                            )
                            .toggleStyle(.button)
                            .controlSize(.mini)
                            Spacer()
                            Button("Recall") {
                                appModel.applyBackdropCueIndex(pair.offset)
                            }
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
    }

    private func importOFLProfile() async {
        let man = oflManufacturer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let slug = oflFixtureSlug.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !man.isEmpty, !slug.isEmpty else {
            await MainActor.run { oflStatus = "Enter manufacturer and fixture slug." }
            return
        }
        do {
            let data = try await OFLFixtureImportService.fetchRawFixture(manufacturer: man, fixture: slug)
            let profile = try OFLFixtureImportService.buildProfile(manufacturer: man, fixture: slug, data: data)
            await MainActor.run {
                var d = appModel.dmxPatchDocument
                d.profiles.append(profile)
                appModel.applyDMXPatchDocument(d)
                oflStatus = "Added profile: \(profile.name)"
            }
        } catch {
            await MainActor.run {
                oflStatus = "Import failed: \(error.localizedDescription)"
            }
        }
    }

    private func syncCuratedOFLCatalog() async {
        do {
            let cache = try await OFLFixtureImportService.syncCuratedCatalog()
            await MainActor.run {
                oflCatalog = cache.entries
                oflStatus = "Synced curated OFL catalog (\(cache.entries.count) fixtures)."
            }
        } catch {
            await MainActor.run {
                oflStatus = "Catalog sync failed: \(error.localizedDescription)"
            }
        }
    }

    private func importSelectedCuratedFixture() async {
        guard let id = selectedCatalogFixtureID,
              let entry = oflCatalog.first(where: { $0.id == id }) else { return }
        do {
            let data = try await OFLFixtureImportService.fetchRawFixture(
                manufacturer: entry.manufacturerSlug,
                fixture: entry.fixtureSlug
            )
            let profile = try OFLFixtureImportService.buildProfile(
                manufacturer: entry.manufacturerSlug,
                fixture: entry.fixtureSlug,
                data: data
            )
            await MainActor.run {
                var d = appModel.dmxPatchDocument
                d.profiles.append(profile)
                appModel.applyDMXPatchDocument(d)
                oflStatus = "Imported curated fixture: \(profile.name)"
            }
        } catch {
            await MainActor.run {
                oflStatus = "Curated import failed: \(error.localizedDescription)"
            }
        }
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

                patchHealthAndDMXStatusRow

                fogHazeLearnSection
                fixtureVerificationSection

                VStack(alignment: .leading, spacing: 4) {
                    Text("Universe 0 · channels 1–32 (live)")
                        .font(.caption.weight(.semibold))
                    DMXUniverseMonitorView(channelCount: 32)
                        .environmentObject(appModel)
                    Text("Values follow the same build as USB output (legacy slots, patch, cues, modulation).")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                profileLibrarySection

                HStack {
                    Button("Add fixture from selected profile") { addFixtureFromSelectedProfile() }
                        .disabled(selectedPatchProfile == nil)
                    Button("Add RGB Par fixture") { addRGBParFixture() }
                    Button("Remove last fixture") { removeLastFixture() }
                        .disabled(appModel.dmxPatchDocument.instances.isEmpty)
                }
                if appModel.dmxPatchDocument.instances.isEmpty {
                    Text("No fixtures patched yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(appModel.dmxPatchDocument.instances.enumerated()), id: \.element.id) { pair in
                        let inst = pair.element
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(appModel.dmxPatchDocument.profile(id: inst.profileID)?.name ?? "Unknown profile")
                                    Spacer()
                                    Text("Fixture \(pair.offset + 1)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Button("Remove", role: .destructive) {
                                        removeFixture(instanceID: inst.id)
                                    }
                                    .controlSize(.small)
                                }
                                if !patchAssignableProfiles(excludingLegacy: true).isEmpty {
                                    Picker("Profile", selection: fixtureProfileBinding(instanceID: inst.id)) {
                                        ForEach(patchAssignableProfiles(excludingLegacy: true)) { profile in
                                            Text(profile.name).tag(profile.id)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                                HStack(spacing: 8) {
                                    Stepper(
                                        "Start address: \(inst.startAddress)",
                                        value: patchStartAddressBinding(instanceID: inst.id),
                                        in: 1 ... 512
                                    )
                                    Button("Next gap") {
                                        suggestNextStartAddress(for: inst.id)
                                    }
                                    .controlSize(.small)
                                }
                                if let profile = appModel.dmxPatchDocument.profile(id: inst.profileID) {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(alignment: .top, spacing: 10) {
                                            ForEach(Array(profile.channels.enumerated()), id: \.offset) { channel in
                                                VStack(spacing: 4) {
                                                    Text(channel.element.label)
                                                        .font(.caption2)
                                                        .lineLimit(1)
                                                    Slider(
                                                        value: manualChannelBinding(instanceID: inst.id, channelIndex: channel.offset),
                                                        in: 0 ... 255
                                                    )
                                                    .frame(width: 90)
                                                    Text("\(Int(manualChannelBinding(instanceID: inst.id, channelIndex: channel.offset).wrappedValue))")
                                                        .font(.caption2.monospacedDigit())
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var cueSection: some View {
        GroupBox("Lighting cues") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button("Capture cue from current patch") { captureCueFromCurrentPatch() }
                    Button("Apply active cue → fixture manuals") { applyActiveCueToFixtureManuals() }
                        .disabled(appModel.lightingCueDocument.activeCueIndex == nil)
                    Button("Delete selected cue", role: .destructive) { deleteSelectedCue() }
                        .disabled(selectedCueBinding.wrappedValue == nil)
                }
                HStack {
                    Button("Move cue up") { moveSelectedCue(by: -1) }
                        .disabled(!canMoveSelectedCue(by: -1))
                    Button("Move cue down") { moveSelectedCue(by: 1) }
                        .disabled(!canMoveSelectedCue(by: 1))
                }
                .controlSize(.small)
                HStack {
                    Button("Duplicate selected cue") { duplicateSelectedCue() }
                        .disabled(selectedCueBinding.wrappedValue == nil)
                    Button("Clear selected cue values") { clearSelectedCueValues() }
                        .disabled(selectedCueBinding.wrappedValue == nil)
                    Button("Set selected cue full") { setSelectedCueFull() }
                        .disabled(selectedCueBinding.wrappedValue == nil)
                    Button("Normalize all cue fades to 1.0s") { normalizeCueFades() }
                        .disabled(appModel.lightingCueDocument.cues.isEmpty)
                }
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
                Picker("Cue editor", selection: selectedCueBinding) {
                    Text("None").tag(Optional<UUID>.none)
                    ForEach(appModel.lightingCueDocument.cues) { cue in
                        Text(cue.name).tag(Optional(cue.id))
                    }
                }
                .pickerStyle(.menu)
                if let cue = selectedCue {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Cue name", text: cueNameBinding(cueID: cue.id))
                            Toggle(
                                "Bookmark for Live Show",
                                isOn: Binding(
                                    get: { appModel.lightingCueDocument.bookmarkedCueIds.contains(cue.id) },
                                    set: { on in
                                        var d = appModel.lightingCueDocument
                                        if on {
                                            if !d.bookmarkedCueIds.contains(cue.id) {
                                                d.bookmarkedCueIds.append(cue.id)
                                            }
                                        } else {
                                            d.bookmarkedCueIds.removeAll { $0 == cue.id }
                                        }
                                        appModel.applyLightingCueDocument(d)
                                    }
                                )
                            )
                            .controlSize(.small)
                            HStack {
                                Text("Fade: \(String(format: "%.2fs", cue.fadeSeconds))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Slider(value: cueFadeBinding(cueID: cue.id), in: 0 ... 12)
                            }
                            Toggle(
                                "Auto hazer envelope (rise + hold from preset)",
                                isOn: cueAutoEnvelopeBinding(cueID: cue.id)
                            )
                            .disabled(cue.hazeLearnPreset == nil)
                            .controlSize(.small)
                            if let p = cue.hazeLearnPreset {
                                Text(
                                    "Preset: steady DMX \(p.steadyHazeDMX), rise \(String(format: "%.1f", p.riseTimeSeconds))s, decay τ ~\(String(format: "%.1f", p.dissipationHalfLifeSeconds))s"
                                )
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }
                            Text("Channel values")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ForEach(cueEditorGroups(for: cue), id: \.title) { group in
                                GroupBox(group.title) {
                                    if let fixtureID = group.fixtureID {
                                        HStack(spacing: 8) {
                                            Button("All Off") {
                                                setCueValuesForFixture(cueID: cue.id, fixtureID: fixtureID, value: 0)
                                            }
                                            Button("All Full") {
                                                setCueValuesForFixture(cueID: cue.id, fixtureID: fixtureID, value: 255)
                                            }
                                            Button("RGB Off") {
                                                setCueValuesForFixtureRoles(cueID: cue.id, fixtureID: fixtureID, roles: [.red, .green, .blue], value: 0)
                                            }
                                            Button("RGB Full") {
                                                setCueValuesForFixtureRoles(cueID: cue.id, fixtureID: fixtureID, roles: [.red, .green, .blue], value: 255)
                                            }
                                        }
                                        .controlSize(.small)
                                    }
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 10) {
                                            ForEach(group.channels, id: \.dmxChannel) { entry in
                                                VStack(spacing: 4) {
                                                    Text(entry.label)
                                                        .font(.caption2)
                                                        .lineLimit(1)
                                                    Slider(
                                                        value: cueChannelValueBinding(cueID: cue.id, channel: entry.dmxChannel),
                                                        in: 0 ... 255
                                                    )
                                                    .frame(width: 88)
                                                    Text("Ch \(entry.dmxChannel)")
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                    Text("\(Int(cueChannelValueBinding(cueID: cue.id, channel: entry.dmxChannel).wrappedValue))")
                                                        .font(.caption2.monospacedDigit())
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var modulationSection: some View {
        GroupBox("Modulation") {
            VStack(alignment: .leading, spacing: 10) {
                Button("Add modulator") { addModulator() }
                if appModel.modulationDocument.modulators.isEmpty {
                    Text("No modulators. Add one to animate DMX channels.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appModel.modulationDocument.modulators) { mod in
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Toggle(mod.name, isOn: modEnabledBinding(mod.id))
                                    Spacer()
                                    Button("Delete", role: .destructive) {
                                        deleteModulator(mod.id)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                TextField("Name", text: modNameBinding(mod.id))
                                Picker("Type", selection: modKindBinding(mod.id)) {
                                    ForEach(ModulatorKind.allCases, id: \.self) { kind in
                                        Text(kind.rawValue).tag(kind)
                                    }
                                }
                                modulatorTargetControls(for: mod)
                                HStack {
                                    Text("Depth")
                                        .font(.caption2)
                                    Slider(value: modDepthBinding(mod.id), in: 0 ... 1)
                                }
                                if mod.kind == .lfoSine || mod.kind == .lfoTriangle {
                                    HStack {
                                        Text("Rate (Hz)")
                                            .font(.caption2)
                                        Slider(value: modRateBinding(mod.id), in: 0.05 ... 8)
                                    }
                                } else if mod.kind == .tempoPulse {
                                    HStack {
                                        Text("Tempo divisions")
                                            .font(.caption2)
                                        Slider(value: modTempoDivisionsBinding(mod.id), in: 0.25 ... 8)
                                    }
                                } else {
                                    HStack {
                                        Text("Smoothing")
                                            .font(.caption2)
                                        Slider(value: modSmoothingBinding(mod.id), in: 0 ... 1)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var jsonTransportSection: some View {
        GroupBox("Templates & JSON transport") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Full lighting workspace")
                    .font(.caption.weight(.semibold))
                HStack {
                    Button("Copy full bundle (patch + cues + modulation + stage)") { exportLightingBundleJSONToClipboard() }
                    Button("Paste clipboard → editor") { pasteLightingBundleFromClipboard() }
                }
                TextEditor(text: $lightingBundleJSON)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 72, maxHeight: 140)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
                    )
                Button("Replace entire workspace from JSON above", role: .destructive) { replaceLightingBundleFromTransportJSON() }
                Text("One-shot backup or transfer: overwrites patch, cue library, modulation, and stage layout.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Divider().padding(.vertical, 4)

                Text("DMX patch document")
                    .font(.caption.weight(.semibold))
                HStack {
                    Button("Copy full patch JSON") { exportFullPatchJSONToClipboard() }
                    Button("Paste clipboard → editor") { pastePatchFromClipboard() }
                }
                TextEditor(text: $patchTransportJSON)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 56, maxHeight: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
                    )
                Button("Replace patch from JSON above", role: .destructive) { replacePatchFromTransportJSON() }
                Text("Replacing the patch rewrites profiles and fixtures. Stage positions are keyed by fixture ID—imports with different IDs may need repositioning on the stage plan.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Divider().padding(.vertical, 4)

                Text("Stage layout")
                    .font(.caption.weight(.semibold))
                HStack {
                    Button("Copy stage layout JSON") { exportStageLayoutJSONToClipboard() }
                    Button("Paste clipboard → editor") { pasteStageLayoutFromClipboard() }
                }
                TextEditor(text: $stageTransportJSON)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 48, maxHeight: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
                    )
                Button("Replace stage layout from JSON above", role: .destructive) { replaceStageLayoutFromTransportJSON() }
                Text("Backdrop paths are absolute; moving JSON between machines may require re-importing the backdrop image.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Divider().padding(.vertical, 4)

                Text("Cue")
                    .font(.caption.weight(.semibold))
                HStack {
                    Button("Copy selected cue JSON") { exportSelectedCueJSONToClipboard() }
                        .disabled(selectedCueID == nil)
                    Button("Paste clipboard → editor") { pasteCueFromClipboard() }
                }
                TextEditor(text: $cueTransportJSON)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 72, maxHeight: 140)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
                    )
                Button("Import cue from JSON above") { importCueFromTransportJSON() }
                HStack(alignment: .top, spacing: 8) {
                    Button("Copy full cue library") { exportFullCueLibraryJSONToClipboard() }
                    Button("Merge cues from JSON above") { mergeCuesFromLibraryJSON() }
                    Button("Replace library from JSON", role: .destructive) { replaceCueLibraryFromJSON() }
                }
                .controlSize(.small)

                Divider().padding(.vertical, 4)

                Text("Fixture profile")
                    .font(.caption.weight(.semibold))
                HStack {
                    Button("Copy selected profile JSON") { exportSelectedProfileJSONToClipboard() }
                        .disabled(selectedProfileID == nil)
                    Button("Paste clipboard → editor") { pasteProfileFromClipboard() }
                }
                TextEditor(text: $profileTransportJSON)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 72, maxHeight: 140)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
                    )
                Button("Import profile from JSON above") { importProfileFromTransportJSON() }

                Divider().padding(.vertical, 4)

                Text("Modulation")
                    .font(.caption.weight(.semibold))
                HStack {
                    Button("Copy modulation document JSON") { exportModulationJSONToClipboard() }
                    Button("Paste clipboard → editor") { pasteModulationFromClipboard() }
                }
                TextEditor(text: $modulationTransportJSON)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 56, maxHeight: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
                    )
                Button("Replace modulation from JSON above", role: .destructive) { replaceModulationFromTransportJSON() }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var patchHealthAndDMXStatusRow: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            VStack(alignment: .leading, spacing: 6) {
                let conflicts = DMXPatchAudit.universeZeroConflictMessages(patch: appModel.dmxPatchDocument)
                if !conflicts.isEmpty {
                    Text("Address conflicts (universe 0)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    ForEach(Array(conflicts.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                let d = appModel.dmxOutputDiagnostics()
                HStack(alignment: .top, spacing: 8) {
                    Text("USB DMX")
                        .font(.caption.weight(.semibold))
                    if appModel.remoteSettings.dmxOutputEnabled {
                        Text(d.running ? "streaming ~\(Int(d.nominalHz)) Hz" : "enabled · idle (check device path in Settings)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("off (enable in Settings)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let err = d.lastError, !err.isEmpty {
                        Text(err)
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }

    private var hazerInstances: [FixtureInstance] {
        appModel.dmxPatchDocument.instances.filter { inst in
            guard let p = appModel.dmxPatchDocument.profile(id: inst.profileID) else { return false }
            return p.channels.contains { $0.role == .hazeOutput }
        }
    }

    private var fogHazeLearnSection: some View {
        GroupBox("Fog / haze learn (camera luma)") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Brightens non-hazer channels, ramps the hazer while sampling camera luma, measures dissipation, brief strobe confirm, restores the patch, and writes a preset on the cue you pick. Grant camera access when prompted.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Target cue", selection: $fogLearnCueID) {
                    Text("Select…").tag(Optional<UUID>.none)
                    ForEach(appModel.lightingCueDocument.cues) { c in
                        Text(c.name).tag(Optional(c.id))
                    }
                }
                Picker("Hazer fixture", selection: $fogLearnHazerID) {
                    Text("Select…").tag(Optional<UUID>.none)
                    ForEach(hazerInstances, id: \.id) { inst in
                        Text(fogLearnHazerMenuLabel(inst)).tag(Optional(inst.id))
                    }
                }
                if hazerInstances.isEmpty {
                    Text("Patch a fixture whose profile includes “hazeOutput” (e.g. built-in Fog / haze).")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                if !appModel.fogHazeLearnPhase.isEmpty {
                    Text(appModel.fogHazeLearnPhase)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button("Start learn") {
                        guard let cid = fogLearnCueID, let hid = fogLearnHazerID else { return }
                        appModel.startFogHazeLearn(targetCueID: cid, hazerInstanceID: hid, webcam: fogLearnWebcam)
                    }
                    .disabled(fogLearnCueID == nil || fogLearnHazerID == nil)
                    Button("Cancel learn") {
                        appModel.cancelFogHazeLearn()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func fogLearnHazerMenuLabel(_ inst: FixtureInstance) -> String {
        guard let idx = appModel.dmxPatchDocument.instances.firstIndex(where: { $0.id == inst.id }) else {
            return "Hazer"
        }
        let name = appModel.dmxPatchDocument.profile(id: inst.profileID)?.name ?? "Profile"
        return "\(name) #\(idx + 1)"
    }

    private var fixtureVerificationSection: some View {
        GroupBox("Fixture verification (assisted)") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Scans each assigned fixture independently with DMX test bursts and camera luma sampling to validate patching, quantity, venue-map layout, and orientation metadata. Optional secondary wireless iOS Continuity Camera can be angled near stage depth.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !fixtureVerifyAvailableCameras.isEmpty {
                    Picker("Primary scan camera", selection: $fixtureVerifyPrimaryCameraID) {
                        Text("System default").tag(Optional<String>.none)
                        ForEach(fixtureVerifyAvailableCameras, id: \.uniqueID) { device in
                            Text(cameraLabel(device)).tag(Optional(device.uniqueID))
                        }
                    }
                    .pickerStyle(.menu)
                }
                Toggle("Use secondary angled camera (Continuity/iOS recommended)", isOn: $fixtureVerifyUseSecondaryCamera)
                    .controlSize(.small)
                if fixtureVerifyUseSecondaryCamera, !fixtureVerifyAvailableCameras.isEmpty {
                    Picker("Secondary scan camera", selection: $fixtureVerifySecondaryCameraID) {
                        Text("Select secondary camera…").tag(Optional<String>.none)
                        ForEach(fixtureVerifyAvailableCameras.filter { $0.uniqueID != fixtureVerifyPrimaryCameraID }, id: \.uniqueID) { device in
                            Text(cameraLabel(device)).tag(Optional(device.uniqueID))
                        }
                    }
                    .pickerStyle(.menu)
                    Text("Place this camera close to stage edge at an angle to better resolve depth/location. Stage plot shows required scan wedges.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button("Start fixture verification") {
                        appModel.startFixtureVerification(
                            primaryWebcam: fixtureVerifyWebcam,
                            primaryDeviceUniqueID: fixtureVerifyPrimaryCameraID,
                            secondaryWebcam: fixtureVerifyUseSecondaryCamera ? fixtureVerifySecondaryWebcam : nil,
                            secondaryDeviceUniqueID: fixtureVerifySecondaryCameraID
                        )
                    }
                    Button("Cancel verification") {
                        appModel.cancelFixtureVerification()
                    }
                }
                if !appModel.fixtureVerificationPhase.isEmpty {
                    Text(appModel.fixtureVerificationPhase)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let report = appModel.fixtureVerificationReport {
                    HStack(spacing: 10) {
                        categoryBadge("Patching", status: aggregateStatus(report.fixtures.map(\.patching.status)))
                        categoryBadge("Quantity", status: aggregateStatus(report.fixtures.map(\.quantity.status)))
                        categoryBadge("Layout", status: aggregateStatus(report.fixtures.map(\.layout.status)))
                        categoryBadge("Orientation", status: aggregateStatus(report.fixtures.map(\.orientation.status)))
                    }
                    .font(.caption2)
                    ForEach(report.fixtures) { fixture in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("#\(fixture.fixtureIndex) \(fixture.fixtureName) @ \(fixture.startAddress)")
                                .font(.caption.weight(.semibold))
                            Text("Patch \(fixture.patching.status.rawValue): \(fixture.patching.note)")
                                .font(.caption2)
                            Text("Layout \(fixture.layout.status.rawValue): \(fixture.layout.note)")
                                .font(.caption2)
                            Text("Orientation \(fixture.orientation.status.rawValue): \(fixture.orientation.note)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            if fixtureVerifyAvailableCameras.isEmpty {
                fixtureVerifyAvailableCameras = WebcamCaptureService.availableVideoDevices()
            }
        }
    }

    private func cameraLabel(_ device: AVCaptureDevice) -> String {
        if device.deviceType == .continuityCamera {
            return "\(device.localizedName) (Continuity)"
        }
        return device.localizedName
    }

    private func aggregateStatus(_ statuses: [FixtureVerificationStatus]) -> FixtureVerificationStatus {
        if statuses.contains(.fail) { return .fail }
        if statuses.contains(.warn) { return .warn }
        return .pass
    }

    private func categoryBadge(_ title: String, status: FixtureVerificationStatus) -> some View {
        let color: Color
        switch status {
        case .pass: color = .green
        case .fail: color = .red
        case .warn: color = .orange
        }
        return Text("\(title): \(status.rawValue.uppercased())")
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func cueAutoEnvelopeBinding(cueID: UUID) -> Binding<Bool> {
        Binding(
            get: {
                appModel.lightingCueDocument.cues.first { $0.id == cueID }?.autoApplyHazeEnvelope ?? false
            },
            set: { v in
                var d = appModel.lightingCueDocument
                guard let i = d.cues.firstIndex(where: { $0.id == cueID }) else { return }
                d.cues[i].autoApplyHazeEnvelope = v
                appModel.applyLightingCueDocument(d)
            }
        )
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
                    HStack(alignment: .top) {
                        Text(copilotStatus)
                            .font(.caption)
                        Spacer(minLength: 8)
                        Button("Clear status") {
                            copilotStatus = ""
                        }
                        .controlSize(.small)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var selectedCue: LightingCue? {
        guard let id = selectedCueID else { return nil }
        return appModel.lightingCueDocument.cues.first(where: { $0.id == id })
    }

    private var selectedCueBinding: Binding<UUID?> {
        Binding(
            get: { selectedCueID },
            set: { selectedCueID = $0 }
        )
    }

    private struct CueEditorGroup {
        var title: String
        var fixtureID: UUID?
        var channels: [CueEditorChannel]
    }

    private struct CueEditorChannel {
        var dmxChannel: Int
        var label: String
        var role: FixtureChannelRole
    }

    private func cueEditorGroups(for cue: LightingCue) -> [CueEditorGroup] {
        var grouped: [String: CueEditorGroup] = [:]
        for channelValue in cue.channelValues.sorted(by: { $0.channel < $1.channel }) {
            let channel = channelValue.channel
            if let mapped = mappedFixtureChannel(forDMXChannel: channel) {
                if grouped[mapped.fixtureTitle] == nil {
                    grouped[mapped.fixtureTitle] = CueEditorGroup(title: mapped.fixtureTitle, fixtureID: mapped.fixtureID, channels: [])
                }
                grouped[mapped.fixtureTitle]?.channels.append(
                    CueEditorChannel(dmxChannel: channel, label: mapped.channelLabel, role: mapped.role)
                )
            } else {
                if grouped["Unpatched channels"] == nil {
                    grouped["Unpatched channels"] = CueEditorGroup(title: "Unpatched channels", fixtureID: nil, channels: [])
                }
                grouped["Unpatched channels"]?.channels.append(
                    CueEditorChannel(dmxChannel: channel, label: "Ch \(channel)", role: .generic)
                )
            }
        }
        return grouped.keys.sorted().compactMap { grouped[$0] }
    }

    private func mappedFixtureChannel(forDMXChannel channel: Int) -> (fixtureTitle: String, fixtureID: UUID, channelLabel: String, role: FixtureChannelRole)? {
        for inst in appModel.dmxPatchDocument.instances {
            guard let profile = appModel.dmxPatchDocument.profile(id: inst.profileID) else { continue }
            let start = inst.startAddress
            let end = start + profile.channels.count - 1
            guard channel >= start, channel <= end else { continue }
            let idx = channel - start
            guard profile.channels.indices.contains(idx) else { continue }
            return ("\(profile.name) @ \(start)", inst.id, profile.channels[idx].label, profile.channels[idx].role)
        }
        return nil
    }

    private var selectedPatchProfile: FixtureProfile? {
        guard let id = selectedProfileID else { return nil }
        return appModel.dmxPatchDocument.profiles.first(where: { $0.id == id })
    }

    private var profileLibrarySection: some View {
        GroupBox("Fixture profiles") {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Profile", selection: profileSelectionBinding) {
                    Text("None").tag(Optional<UUID>.none)
                    ForEach(patchAssignableProfiles(excludingLegacy: false)) { profile in
                        Text(profile.name).tag(Optional(profile.id))
                    }
                }
                .pickerStyle(.menu)
                HStack {
                    Button("New profile") { createProfile() }
                    Button("Duplicate profile") { duplicateSelectedProfile() }
                        .disabled(selectedProfileID == nil)
                    Button("Delete profile", role: .destructive) { deleteSelectedProfile() }
                        .disabled(!canDeleteSelectedProfile)
                }
                if let profile = selectedPatchProfile {
                    TextField("Profile name", text: profileNameBinding(profile.id))
                    if profile.channels.isEmpty {
                        Text("No channels. Add one below.")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    } else {
                        ForEach(Array(profile.channels.enumerated()), id: \.offset) { pair in
                            HStack {
                                TextField("Label", text: profileChannelLabelBinding(profileID: profile.id, channelIndex: pair.offset))
                                Picker("Role", selection: profileChannelRoleBinding(profileID: profile.id, channelIndex: pair.offset)) {
                                    ForEach(FixtureChannelRole.allCases, id: \.self) { role in
                                        Text(role.rawValue).tag(role)
                                    }
                                }
                                .pickerStyle(.menu)
                                Button(role: .destructive) {
                                    removeProfileChannel(profileID: profile.id, channelIndex: pair.offset)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    Button("Add channel") { addProfileChannel(profileID: profile.id) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var profileSelectionBinding: Binding<UUID?> {
        Binding(
            get: { selectedProfileID },
            set: { selectedProfileID = $0 }
        )
    }

    private var canDeleteSelectedProfile: Bool {
        guard let selectedProfileID else { return false }
        guard let profile = appModel.dmxPatchDocument.profile(id: selectedProfileID) else { return false }
        guard profile.name != FixtureProfile.builtInLegacyVisualization().name else { return false }
        guard profile.name != FixtureProfile.builtInRGBPar().name else { return false }
        let isUsed = appModel.dmxPatchDocument.instances.contains { $0.profileID == selectedProfileID }
        return !isUsed
    }

    private func patchAssignableProfiles(excludingLegacy: Bool) -> [FixtureProfile] {
        appModel.dmxPatchDocument.profiles.filter { profile in
            if !excludingLegacy { return true }
            return profile.name != FixtureProfile.builtInLegacyVisualization().name
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

    private func createProfile() {
        var patch = appModel.dmxPatchDocument
        let profile = FixtureProfile(
            name: "Custom fixture \(patch.profiles.count + 1)",
            channels: [
                FixtureChannelDef(label: "Dimmer", role: .intensity),
                FixtureChannelDef(label: "Red", role: .red),
                FixtureChannelDef(label: "Green", role: .green),
                FixtureChannelDef(label: "Blue", role: .blue),
            ]
        )
        patch.profiles.append(profile)
        selectedProfileID = profile.id
        appModel.applyDMXPatchDocument(patch)
    }

    private func deleteSelectedProfile() {
        guard let selectedProfileID, canDeleteSelectedProfile else { return }
        var patch = appModel.dmxPatchDocument
        patch.profiles.removeAll { $0.id == selectedProfileID }
        appModel.applyDMXPatchDocument(patch)
        self.selectedProfileID = nil
    }

    private func duplicateSelectedProfile() {
        guard let pid = selectedProfileID, let profile = appModel.dmxPatchDocument.profile(id: pid) else { return }
        var patch = appModel.dmxPatchDocument
        let copy = FixtureProfile(
            id: UUID(),
            name: profile.name + " Copy",
            channels: profile.channels
        )
        patch.profiles.append(copy)
        selectedProfileID = copy.id
        appModel.applyDMXPatchDocument(patch)
        copilotStatus = "Duplicated profile as \"\(copy.name)\"."
    }

    private func profileNameBinding(_ profileID: UUID) -> Binding<String> {
        Binding(
            get: { appModel.dmxPatchDocument.profile(id: profileID)?.name ?? "" },
            set: { value in
                var patch = appModel.dmxPatchDocument
                guard let idx = patch.profiles.firstIndex(where: { $0.id == profileID }) else { return }
                patch.profiles[idx].name = value
                appModel.applyDMXPatchDocument(patch)
            }
        )
    }

    private func profileChannelLabelBinding(profileID: UUID, channelIndex: Int) -> Binding<String> {
        Binding(
            get: {
                guard let profile = appModel.dmxPatchDocument.profile(id: profileID),
                      profile.channels.indices.contains(channelIndex)
                else { return "" }
                return profile.channels[channelIndex].label
            },
            set: { value in
                var patch = appModel.dmxPatchDocument
                guard let p = patch.profiles.firstIndex(where: { $0.id == profileID }),
                      patch.profiles[p].channels.indices.contains(channelIndex)
                else { return }
                patch.profiles[p].channels[channelIndex].label = value
                appModel.applyDMXPatchDocument(patch)
            }
        )
    }

    private func profileChannelRoleBinding(profileID: UUID, channelIndex: Int) -> Binding<FixtureChannelRole> {
        Binding(
            get: {
                guard let profile = appModel.dmxPatchDocument.profile(id: profileID),
                      profile.channels.indices.contains(channelIndex)
                else { return .generic }
                return profile.channels[channelIndex].role
            },
            set: { role in
                var patch = appModel.dmxPatchDocument
                guard let p = patch.profiles.firstIndex(where: { $0.id == profileID }),
                      patch.profiles[p].channels.indices.contains(channelIndex)
                else { return }
                patch.profiles[p].channels[channelIndex].role = role
                appModel.applyDMXPatchDocument(patch)
            }
        )
    }

    private func addProfileChannel(profileID: UUID) {
        var patch = appModel.dmxPatchDocument
        guard let idx = patch.profiles.firstIndex(where: { $0.id == profileID }) else { return }
        patch.profiles[idx].channels.append(FixtureChannelDef(label: "Channel \(patch.profiles[idx].channels.count + 1)", role: .generic))
        appModel.applyDMXPatchDocument(patch)
    }

    private func removeProfileChannel(profileID: UUID, channelIndex: Int) {
        var patch = appModel.dmxPatchDocument
        guard let idx = patch.profiles.firstIndex(where: { $0.id == profileID }),
              patch.profiles[idx].channels.indices.contains(channelIndex)
        else { return }
        patch.profiles[idx].channels.remove(at: channelIndex)
        appModel.applyDMXPatchDocument(patch)
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

    private func addFixtureFromSelectedProfile() {
        guard let profile = selectedPatchProfile else { return }
        var patch = appModel.dmxPatchDocument
        let addr = appModel.lightingCopilotService.suggestNextAddresses(patch: patch, profile: profile, count: 1).first ?? 6
        var defaultManual: [String: UInt8] = [:]
        for idx in profile.channels.indices {
            defaultManual[String(idx)] = profile.channels[idx].role == .intensity ? 200 : 0
        }
        let inst = FixtureInstance(profileID: profile.id, startAddress: addr, manualValues: defaultManual)
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

    private func removeFixture(instanceID: UUID) {
        var patch = appModel.dmxPatchDocument
        guard let rmIdx = patch.instances.firstIndex(where: { $0.id == instanceID }) else { return }
        patch.instances.remove(at: rmIdx)
        appModel.applyDMXPatchDocument(patch)
        var stage = appModel.stageLayoutDocument
        stage.placements.removeValue(forKey: instanceID.uuidString)
        appModel.applyStageLayoutDocument(stage)
        copilotStatus = "Removed fixture from patch and stage."
    }

    private func patchStartAddressBinding(instanceID: UUID) -> Binding<Int> {
        Binding(
            get: {
                appModel.dmxPatchDocument.instances.first(where: { $0.id == instanceID })?.startAddress ?? 1
            },
            set: { addr in
                var patch = appModel.dmxPatchDocument
                guard let idx = patch.instances.firstIndex(where: { $0.id == instanceID }) else { return }
                patch.instances[idx].startAddress = max(1, min(512, addr))
                appModel.applyDMXPatchDocument(patch)
            }
        )
    }

    private func suggestNextStartAddress(for instanceID: UUID) {
        var patch = appModel.dmxPatchDocument
        guard let idx = patch.instances.firstIndex(where: { $0.id == instanceID }),
              let profile = patch.profile(id: patch.instances[idx].profileID)
        else { return }
        let addrs = appModel.lightingCopilotService.suggestNextAddresses(
            patch: patch,
            profile: profile,
            count: 1,
            excludingInstanceIDs: Set([instanceID])
        )
        guard let addr = addrs.first else {
            copilotStatus = "No contiguous span found for this fixture’s channel width."
            return
        }
        patch.instances[idx].startAddress = addr
        appModel.applyDMXPatchDocument(patch)
        copilotStatus = "Moved fixture to next free start address \(addr)."
    }

    private func fixtureProfileBinding(instanceID: UUID) -> Binding<UUID> {
        Binding(
            get: {
                appModel.dmxPatchDocument.instances.first(where: { $0.id == instanceID })?.profileID
                    ?? patchAssignableProfiles(excludingLegacy: true).first?.id
                    ?? UUID()
            },
            set: { profileID in
                var patch = appModel.dmxPatchDocument
                guard let idx = patch.instances.firstIndex(where: { $0.id == instanceID }) else { return }
                patch.instances[idx].profileID = profileID
                patch.instances[idx].manualValues = [:]
                appModel.applyDMXPatchDocument(patch)
            }
        )
    }

    private func manualChannelBinding(instanceID: UUID, channelIndex: Int) -> Binding<Float> {
        Binding(
            get: {
                guard let inst = appModel.dmxPatchDocument.instances.first(where: { $0.id == instanceID }) else { return 0 }
                return Float(inst.manual(forChannelIndex: channelIndex))
            },
            set: { value in
                var patch = appModel.dmxPatchDocument
                guard let idx = patch.instances.firstIndex(where: { $0.id == instanceID }) else { return }
                patch.instances[idx].setManual(channelIndex: channelIndex, value: UInt8(max(0, min(255, Int(value.rounded())))))
                appModel.applyDMXPatchDocument(patch)
            }
        )
    }

    private func applyActiveCueToFixtureManuals() {
        guard let ai = appModel.lightingCueDocument.activeCueIndex,
              appModel.lightingCueDocument.cues.indices.contains(ai)
        else {
            copilotStatus = "Pick an active cue first (Active cue picker)."
            return
        }
        let cue = appModel.lightingCueDocument.cues[ai]
        let cmap = cue.channelMap
        var patch = appModel.dmxPatchDocument
        var updated = 0
        for i in patch.instances.indices {
            guard let profile = patch.profile(id: patch.instances[i].profileID) else { continue }
            for idx in profile.channels.indices {
                let dmx = patch.instances[i].startAddress + idx
                guard let v = cmap[dmx] else { continue }
                patch.instances[i].setManual(channelIndex: idx, value: v)
                updated += 1
            }
        }
        appModel.applyDMXPatchDocument(patch)
        copilotStatus = "Applied active cue \"\(cue.name)\" to \(updated) channel slot(s) on fixture manuals."
    }

    private func captureCueFromCurrentPatch() {
        var channelValues: [ChannelValue] = []
        for inst in appModel.dmxPatchDocument.instances {
            guard let profile = appModel.dmxPatchDocument.profile(id: inst.profileID) else { continue }
            for idx in profile.channels.indices {
                let dmxChannel = inst.startAddress + idx
                guard dmxChannel >= 1, dmxChannel <= 512 else { continue }
                channelValues.append(ChannelValue(channel: dmxChannel, value: inst.manual(forChannelIndex: idx)))
            }
        }
        channelValues.sort { $0.channel < $1.channel }
        var doc = appModel.lightingCueDocument
        let cue = LightingCue(
            name: "Cue \(doc.cues.count + 1)",
            fadeSeconds: 1,
            channelValues: channelValues
        )
        doc.cues.append(cue)
        doc.activeCueIndex = doc.cues.count - 1
        selectedCueID = cue.id
        appModel.applyLightingCueDocument(doc)
    }

    private func deleteSelectedCue() {
        guard let cueID = selectedCueID else { return }
        var doc = appModel.lightingCueDocument
        guard let idx = doc.cues.firstIndex(where: { $0.id == cueID }) else { return }
        doc.cues.remove(at: idx)
        if let active = doc.activeCueIndex {
            if active == idx {
                doc.activeCueIndex = nil
            } else if active > idx {
                doc.activeCueIndex = active - 1
            }
        }
        selectedCueID = nil
        appModel.applyLightingCueDocument(doc)
    }

    private func duplicateSelectedCue() {
        guard let cueID = selectedCueID else { return }
        var doc = appModel.lightingCueDocument
        guard let idx = doc.cues.firstIndex(where: { $0.id == cueID }) else { return }
        let src = doc.cues[idx]
        let copy = LightingCue(
            name: "\(src.name) Copy",
            fadeSeconds: src.fadeSeconds,
            channelValues: src.channelValues,
            previewThumbnailPath: src.previewThumbnailPath,
            hazeLearnPreset: src.hazeLearnPreset,
            autoApplyHazeEnvelope: src.autoApplyHazeEnvelope
        )
        doc.cues.insert(copy, at: idx + 1)
        selectedCueID = copy.id
        doc.activeCueIndex = idx + 1
        appModel.applyLightingCueDocument(doc)
    }

    private func canMoveSelectedCue(by offset: Int) -> Bool {
        guard let cueID = selectedCueID,
              let idx = appModel.lightingCueDocument.cues.firstIndex(where: { $0.id == cueID })
        else { return false }
        let newIdx = idx + offset
        return appModel.lightingCueDocument.cues.indices.contains(newIdx)
    }

    private func moveSelectedCue(by offset: Int) {
        guard let cueID = selectedCueID else { return }
        var doc = appModel.lightingCueDocument
        guard let idx = doc.cues.firstIndex(where: { $0.id == cueID }) else { return }
        let newIdx = idx + offset
        guard doc.cues.indices.contains(newIdx) else { return }
        let activeCueId: UUID? = doc.activeCueIndex.flatMap { i in
            doc.cues.indices.contains(i) ? doc.cues[i].id : nil
        }
        doc.cues.swapAt(idx, newIdx)
        if let aid = activeCueId, let ai = doc.cues.firstIndex(where: { $0.id == aid }) {
            doc.activeCueIndex = ai
        }
        appModel.applyLightingCueDocument(doc)
        copilotStatus = "Moved cue in list."
    }

    private func clearSelectedCueValues() {
        guard let cueID = selectedCueID else { return }
        var doc = appModel.lightingCueDocument
        guard let idx = doc.cues.firstIndex(where: { $0.id == cueID }) else { return }
        for valueIndex in doc.cues[idx].channelValues.indices {
            doc.cues[idx].channelValues[valueIndex].value = 0
        }
        appModel.applyLightingCueDocument(doc)
    }

    private func setSelectedCueFull() {
        guard let cueID = selectedCueID else { return }
        var doc = appModel.lightingCueDocument
        guard let idx = doc.cues.firstIndex(where: { $0.id == cueID }) else { return }
        for valueIndex in doc.cues[idx].channelValues.indices {
            doc.cues[idx].channelValues[valueIndex].value = 255
        }
        appModel.applyLightingCueDocument(doc)
    }

    private func setCueValuesForFixture(cueID: UUID, fixtureID: UUID, value: UInt8) {
        var doc = appModel.lightingCueDocument
        guard let cueIndex = doc.cues.firstIndex(where: { $0.id == cueID }),
              let fixture = appModel.dmxPatchDocument.instances.first(where: { $0.id == fixtureID }),
              let profile = appModel.dmxPatchDocument.profile(id: fixture.profileID)
        else { return }
        let channels = profile.channels.indices.map { fixture.startAddress + $0 }
        for channel in channels {
            if let idx = doc.cues[cueIndex].channelValues.firstIndex(where: { $0.channel == channel }) {
                doc.cues[cueIndex].channelValues[idx].value = value
            }
        }
        appModel.applyLightingCueDocument(doc)
    }

    private func setCueValuesForFixtureRoles(
        cueID: UUID,
        fixtureID: UUID,
        roles: [FixtureChannelRole],
        value: UInt8
    ) {
        var doc = appModel.lightingCueDocument
        guard let cueIndex = doc.cues.firstIndex(where: { $0.id == cueID }),
              let fixture = appModel.dmxPatchDocument.instances.first(where: { $0.id == fixtureID }),
              let profile = appModel.dmxPatchDocument.profile(id: fixture.profileID)
        else { return }
        for (idx, channelDef) in profile.channels.enumerated() where roles.contains(channelDef.role) {
            let dmxChannel = fixture.startAddress + idx
            if let valueIndex = doc.cues[cueIndex].channelValues.firstIndex(where: { $0.channel == dmxChannel }) {
                doc.cues[cueIndex].channelValues[valueIndex].value = value
            }
        }
        appModel.applyLightingCueDocument(doc)
    }

    private func normalizeCueFades() {
        var doc = appModel.lightingCueDocument
        for idx in doc.cues.indices {
            doc.cues[idx].fadeSeconds = 1
        }
        appModel.applyLightingCueDocument(doc)
    }

    private func cueNameBinding(cueID: UUID) -> Binding<String> {
        Binding(
            get: {
                appModel.lightingCueDocument.cues.first(where: { $0.id == cueID })?.name ?? ""
            },
            set: { value in
                var doc = appModel.lightingCueDocument
                guard let idx = doc.cues.firstIndex(where: { $0.id == cueID }) else { return }
                doc.cues[idx].name = value
                appModel.applyLightingCueDocument(doc)
            }
        )
    }

    private func cueFadeBinding(cueID: UUID) -> Binding<Double> {
        Binding(
            get: {
                appModel.lightingCueDocument.cues.first(where: { $0.id == cueID })?.fadeSeconds ?? 1
            },
            set: { value in
                var doc = appModel.lightingCueDocument
                guard let idx = doc.cues.firstIndex(where: { $0.id == cueID }) else { return }
                doc.cues[idx].fadeSeconds = max(0, value)
                appModel.applyLightingCueDocument(doc)
            }
        )
    }

    private func cueChannelValueBinding(cueID: UUID, channel: Int) -> Binding<Float> {
        Binding(
            get: {
                guard let cue = appModel.lightingCueDocument.cues.first(where: { $0.id == cueID }),
                      let cv = cue.channelValues.first(where: { $0.channel == channel })
                else { return 0 }
                return Float(cv.value)
            },
            set: { value in
                var doc = appModel.lightingCueDocument
                guard let cueIndex = doc.cues.firstIndex(where: { $0.id == cueID }) else { return }
                if let valueIndex = doc.cues[cueIndex].channelValues.firstIndex(where: { $0.channel == channel }) {
                    doc.cues[cueIndex].channelValues[valueIndex].value = UInt8(max(0, min(255, Int(value.rounded()))))
                }
                appModel.applyLightingCueDocument(doc)
            }
        )
    }

    private func addModulator() {
        var doc = appModel.modulationDocument
        let defaultCh = defaultModulatorDMXChannel()
        doc.modulators.append(
            ModulatorDefinition(
                name: "Mod \(doc.modulators.count + 1)",
                targetChannel: defaultCh,
                kind: .lfoSine,
                depth: 0.35,
                rateHz: 0.5
            )
        )
        appModel.applyModulationDocument(doc)
    }

    private func defaultModulatorDMXChannel() -> Int {
        guard let inst = appModel.dmxPatchDocument.instances.first,
              let profile = appModel.dmxPatchDocument.profile(id: inst.profileID),
              !profile.channels.isEmpty
        else {
            return 10
        }
        return inst.startAddress
    }

    @ViewBuilder
    private func modulatorTargetControls(for mod: ModulatorDefinition) -> some View {
        let patch = appModel.dmxPatchDocument
        if patch.instances.isEmpty {
            Stepper("Target channel: \(mod.targetChannel)", value: modChannelBinding(mod.id), in: 1 ... 512)
            Text("Patch a fixture to choose profile channels instead of raw DMX.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else if DMXPatchAudit.fixtureAndProfileIndex(forDMXChannel: mod.targetChannel, patch: patch) != nil {
            VStack(alignment: .leading, spacing: 6) {
                Picker("Fixture", selection: modTargetFixtureBinding(mod.id)) {
                    ForEach(patch.instances, id: \.id) { inst in
                        Text(modulatorFixtureMenuLabel(inst)).tag(inst.id)
                    }
                }
                .pickerStyle(.menu)
                if let m = DMXPatchAudit.fixtureAndProfileIndex(forDMXChannel: mod.targetChannel, patch: patch),
                   let profile = patch.profile(id: m.instance.profileID) {
                    Picker("Profile channel", selection: modTargetChannelIndexBinding(mod.id)) {
                        ForEach(Array(profile.channels.enumerated()), id: \.offset) { idx, ch in
                            let dmx = m.instance.startAddress + idx
                            Text("\(ch.label) · DMX \(dmx)").tag(idx)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Text("Modulating DMX channel \(mod.targetChannel)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Stepper("Target channel: \(mod.targetChannel)", value: modChannelBinding(mod.id), in: 1 ... 512)
                Text("No fixture uses this channel on universe 0. Enter a valid address or snap below.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                Button("Snap to first fixture, first channel") {
                    snapModulatorToFirstPatchChannel(modID: mod.id)
                }
                .controlSize(.small)
            }
        }
    }

    private func modulatorFixtureMenuLabel(_ instance: FixtureInstance) -> String {
        guard let idx = appModel.dmxPatchDocument.instances.firstIndex(where: { $0.id == instance.id }) else {
            return "Fixture"
        }
        let name = appModel.dmxPatchDocument.profile(id: instance.profileID)?.name ?? "Profile"
        return "\(name) #\(idx + 1)"
    }

    private func modulatorTargetChannel(_ modID: UUID) -> Int {
        appModel.modulationDocument.modulators.first { $0.id == modID }?.targetChannel ?? 1
    }

    private func modTargetFixtureBinding(_ modID: UUID) -> Binding<UUID> {
        Binding(
            get: {
                let patch = appModel.dmxPatchDocument
                let ch = modulatorTargetChannel(modID)
                if let m = DMXPatchAudit.fixtureAndProfileIndex(forDMXChannel: ch, patch: patch) {
                    return m.instance.id
                }
                return patch.instances.first!.id
            },
            set: { instID in
                guard let inst = appModel.dmxPatchDocument.instances.first(where: { $0.id == instID }),
                      let profile = appModel.dmxPatchDocument.profile(id: inst.profileID),
                      !profile.channels.isEmpty else { return }
                let oldCh = modulatorTargetChannel(modID)
                let oldIdx = DMXPatchAudit.fixtureAndProfileIndex(forDMXChannel: oldCh, patch: appModel.dmxPatchDocument)?.channelIndex ?? 0
                let safeIdx = min(oldIdx, profile.channels.count - 1)
                updateModulator(modID) { $0.targetChannel = inst.startAddress + safeIdx }
            }
        )
    }

    private func modTargetChannelIndexBinding(_ modID: UUID) -> Binding<Int> {
        Binding(
            get: {
                let ch = modulatorTargetChannel(modID)
                return DMXPatchAudit.fixtureAndProfileIndex(forDMXChannel: ch, patch: appModel.dmxPatchDocument)?.channelIndex ?? 0
            },
            set: { idx in
                let ch = modulatorTargetChannel(modID)
                guard let m = DMXPatchAudit.fixtureAndProfileIndex(forDMXChannel: ch, patch: appModel.dmxPatchDocument),
                      let profile = appModel.dmxPatchDocument.profile(id: m.instance.profileID),
                      profile.channels.indices.contains(idx) else { return }
                updateModulator(modID) { $0.targetChannel = m.instance.startAddress + idx }
            }
        )
    }

    private func snapModulatorToFirstPatchChannel(modID: UUID) {
        guard let inst = appModel.dmxPatchDocument.instances.first,
              let profile = appModel.dmxPatchDocument.profile(id: inst.profileID),
              !profile.channels.isEmpty else { return }
        updateModulator(modID) { $0.targetChannel = inst.startAddress }
    }

    private func deleteModulator(_ id: UUID) {
        var doc = appModel.modulationDocument
        doc.modulators.removeAll { $0.id == id }
        appModel.applyModulationDocument(doc)
    }

    private func updateModulator(_ id: UUID, _ update: (inout ModulatorDefinition) -> Void) {
        var doc = appModel.modulationDocument
        guard let idx = doc.modulators.firstIndex(where: { $0.id == id }) else { return }
        update(&doc.modulators[idx])
        appModel.applyModulationDocument(doc)
    }

    private func modEnabledBinding(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { appModel.modulationDocument.modulators.first(where: { $0.id == id })?.enabled ?? false },
            set: { on in updateModulator(id) { $0.enabled = on } }
        )
    }

    private func modNameBinding(_ id: UUID) -> Binding<String> {
        Binding(
            get: { appModel.modulationDocument.modulators.first(where: { $0.id == id })?.name ?? "" },
            set: { v in updateModulator(id) { $0.name = v } }
        )
    }

    private func modKindBinding(_ id: UUID) -> Binding<ModulatorKind> {
        Binding(
            get: { appModel.modulationDocument.modulators.first(where: { $0.id == id })?.kind ?? .lfoSine },
            set: { kind in updateModulator(id) { $0.kind = kind } }
        )
    }

    private func modChannelBinding(_ id: UUID) -> Binding<Int> {
        Binding(
            get: { appModel.modulationDocument.modulators.first(where: { $0.id == id })?.targetChannel ?? 1 },
            set: { v in updateModulator(id) { $0.targetChannel = max(1, min(512, v)) } }
        )
    }

    private func modDepthBinding(_ id: UUID) -> Binding<Float> {
        Binding(
            get: { appModel.modulationDocument.modulators.first(where: { $0.id == id })?.depth ?? 0.5 },
            set: { v in updateModulator(id) { $0.depth = max(0, min(1, v)) } }
        )
    }

    private func modRateBinding(_ id: UUID) -> Binding<Float> {
        Binding(
            get: { appModel.modulationDocument.modulators.first(where: { $0.id == id })?.rateHz ?? 0.25 },
            set: { v in updateModulator(id) { $0.rateHz = max(0.01, v) } }
        )
    }

    private func modSmoothingBinding(_ id: UUID) -> Binding<Float> {
        Binding(
            get: { appModel.modulationDocument.modulators.first(where: { $0.id == id })?.smoothing ?? 0.35 },
            set: { v in updateModulator(id) { $0.smoothing = max(0, min(1, v)) } }
        )
    }

    private func modTempoDivisionsBinding(_ id: UUID) -> Binding<Float> {
        Binding(
            get: { appModel.modulationDocument.modulators.first(where: { $0.id == id })?.tempoDivisions ?? 1 },
            set: { v in updateModulator(id) { $0.tempoDivisions = max(0.25, v) } }
        )
    }

    private static func prettyJSONString<T: Encodable>(_ value: T) -> String? {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func exportSelectedCueJSONToClipboard() {
        guard let id = selectedCueID,
              let cue = appModel.lightingCueDocument.cues.first(where: { $0.id == id })
        else {
            copilotStatus = "Select a cue in Cue editor to export."
            return
        }
        guard let str = Self.prettyJSONString(cue) else {
            copilotStatus = "Cue encode failed."
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(str, forType: .string)
        cueTransportJSON = str
        copilotStatus = "Copied selected cue JSON to clipboard."
    }

    private func pasteCueFromClipboard() {
        guard let str = NSPasteboard.general.string(forType: .string), !str.isEmpty else {
            copilotStatus = "Clipboard is empty."
            return
        }
        cueTransportJSON = str
        copilotStatus = "Pasted into cue JSON editor."
    }

    private func importCueFromTransportJSON() {
        let raw = cueTransportJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            copilotStatus = "Paste JSON into the cue editor first."
            return
        }
        guard let data = raw.data(using: .utf8) else { return }
        do {
            let decoded = try JSONDecoder().decode(LightingCue.self, from: data)
            let newName = decoded.name.hasSuffix(" (imported)") ? decoded.name : decoded.name + " (imported)"
            let cue = LightingCue(
                id: UUID(),
                name: newName,
                fadeSeconds: decoded.fadeSeconds,
                channelValues: decoded.channelValues,
                previewThumbnailPath: decoded.previewThumbnailPath,
                hazeLearnPreset: decoded.hazeLearnPreset,
                autoApplyHazeEnvelope: decoded.autoApplyHazeEnvelope
            )
            var doc = appModel.lightingCueDocument
            doc.cues.append(cue)
            selectedCueID = cue.id
            doc.activeCueIndex = doc.cues.count - 1
            appModel.applyLightingCueDocument(doc)
            copilotStatus = "Imported cue \"\(cue.name)\"."
        } catch {
            copilotStatus = "Cue JSON decode failed: \(error.localizedDescription)"
        }
    }

    private func exportLightingBundleJSONToClipboard() {
        let bundle = LightingWorkspaceBundle(
            dmxPatch: appModel.dmxPatchDocument,
            lightingCues: appModel.lightingCueDocument,
            modulation: appModel.modulationDocument,
            stageLayout: appModel.stageLayoutDocument
        )
        guard let str = Self.prettyJSONString(bundle) else {
            copilotStatus = "Lighting bundle encode failed."
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(str, forType: .string)
        lightingBundleJSON = str
        copilotStatus = "Copied full lighting workspace bundle."
    }

    private func pasteLightingBundleFromClipboard() {
        guard let str = NSPasteboard.general.string(forType: .string), !str.isEmpty else {
            copilotStatus = "Clipboard is empty."
            return
        }
        lightingBundleJSON = str
        copilotStatus = "Pasted into lighting bundle editor."
    }

    private func replaceLightingBundleFromTransportJSON() {
        let raw = lightingBundleJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            copilotStatus = "Paste lighting bundle JSON first."
            return
        }
        guard let data = raw.data(using: .utf8) else { return }
        do {
            let decoded = try JSONDecoder().decode(LightingWorkspaceBundle.self, from: data)
            var p = decoded.dmxPatch
            p.version = DMXPatchDocument.currentVersion
            var lc = decoded.lightingCues
            lc.version = LightingCueDocument.currentVersion
            var mod = decoded.modulation
            mod.version = ModulationDocument.currentVersion
            var st = decoded.stageLayout
            st.version = StageLayoutDocument.currentVersion
            appModel.applyDMXPatchDocument(p)
            appModel.applyLightingCueDocument(lc)
            appModel.applyModulationDocument(mod)
            appModel.applyStageLayoutDocument(st)
            if selectedProfileID.map({ appModel.dmxPatchDocument.profile(id: $0) == nil }) ?? true {
                selectedProfileID = appModel.dmxPatchDocument.profiles.first?.id
            }
            let cueDoc = appModel.lightingCueDocument
            let keepCue = selectedCueID.map { sid in cueDoc.cues.contains(where: { $0.id == sid }) } ?? false
            if !keepCue {
                selectedCueID = cueDoc.activeCueIndex.flatMap { i in
                    cueDoc.cues.indices.contains(i) ? cueDoc.cues[i].id : nil
                } ?? cueDoc.cues.first?.id
            }
            copilotStatus = "Replaced full lighting workspace."
        } catch {
            copilotStatus = "Lighting bundle decode failed: \(error.localizedDescription)"
        }
    }

    private func exportFullPatchJSONToClipboard() {
        let doc = appModel.dmxPatchDocument
        guard let str = Self.prettyJSONString(doc) else {
            copilotStatus = "Patch encode failed."
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(str, forType: .string)
        patchTransportJSON = str
        copilotStatus = "Copied DMX patch (\(doc.profiles.count) profiles, \(doc.instances.count) fixtures)."
    }

    private func pastePatchFromClipboard() {
        guard let str = NSPasteboard.general.string(forType: .string), !str.isEmpty else {
            copilotStatus = "Clipboard is empty."
            return
        }
        patchTransportJSON = str
        copilotStatus = "Pasted into patch JSON editor."
    }

    private func exportStageLayoutJSONToClipboard() {
        let doc = appModel.stageLayoutDocument
        guard let str = Self.prettyJSONString(doc) else {
            copilotStatus = "Stage layout encode failed."
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(str, forType: .string)
        stageTransportJSON = str
        copilotStatus = "Copied stage layout JSON."
    }

    private func pasteStageLayoutFromClipboard() {
        guard let str = NSPasteboard.general.string(forType: .string), !str.isEmpty else {
            copilotStatus = "Clipboard is empty."
            return
        }
        stageTransportJSON = str
        copilotStatus = "Pasted into stage layout editor."
    }

    private func replaceStageLayoutFromTransportJSON() {
        let raw = stageTransportJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            copilotStatus = "Paste stage layout JSON first."
            return
        }
        guard let data = raw.data(using: .utf8) else { return }
        do {
            var doc = try JSONDecoder().decode(StageLayoutDocument.self, from: data)
            doc.version = StageLayoutDocument.currentVersion
            appModel.applyStageLayoutDocument(doc)
            copilotStatus = "Replaced stage layout."
        } catch {
            copilotStatus = "Stage layout JSON decode failed: \(error.localizedDescription)"
        }
    }

    private func replacePatchFromTransportJSON() {
        let raw = patchTransportJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            copilotStatus = "Paste patch JSON first."
            return
        }
        guard let data = raw.data(using: .utf8) else { return }
        do {
            var doc = try JSONDecoder().decode(DMXPatchDocument.self, from: data)
            doc.version = DMXPatchDocument.currentVersion
            appModel.applyDMXPatchDocument(doc)
            if selectedProfileID.map({ appModel.dmxPatchDocument.profile(id: $0) == nil }) ?? true {
                selectedProfileID = appModel.dmxPatchDocument.profiles.first?.id
            }
            copilotStatus = "Replaced DMX patch (\(doc.profiles.count) profiles, \(doc.instances.count) fixtures)."
        } catch {
            copilotStatus = "Patch JSON decode failed: \(error.localizedDescription)"
        }
    }

    private func exportFullCueLibraryJSONToClipboard() {
        let doc = appModel.lightingCueDocument
        guard let str = Self.prettyJSONString(doc) else {
            copilotStatus = "Cue library encode failed."
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(str, forType: .string)
        cueTransportJSON = str
        copilotStatus = "Copied full cue library JSON (\(doc.cues.count) cues)."
    }

    private func mergeCuesFromLibraryJSON() {
        let raw = cueTransportJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            copilotStatus = "Paste JSON into the cue editor first."
            return
        }
        guard let data = raw.data(using: .utf8) else { return }
        do {
            let incoming: [LightingCue]
            if let doc = try? JSONDecoder().decode(LightingCueDocument.self, from: data) {
                incoming = doc.cues
            } else {
                incoming = try JSONDecoder().decode([LightingCue].self, from: data)
            }
            guard !incoming.isEmpty else {
                copilotStatus = "No cues in JSON."
                return
            }
            var current = appModel.lightingCueDocument
            var added = 0
            for cue in incoming {
                let name = cue.name.hasSuffix(" (imported)") ? cue.name : cue.name + " (imported)"
                let copy = LightingCue(
                    id: UUID(),
                    name: name,
                    fadeSeconds: cue.fadeSeconds,
                    channelValues: cue.channelValues,
                    previewThumbnailPath: cue.previewThumbnailPath,
                    hazeLearnPreset: cue.hazeLearnPreset,
                    autoApplyHazeEnvelope: cue.autoApplyHazeEnvelope
                )
                current.cues.append(copy)
                added += 1
            }
            appModel.applyLightingCueDocument(current)
            copilotStatus = "Merged \(added) imported cue(s); new UUIDs assigned."
        } catch {
            copilotStatus = "Merge decode failed: \(error.localizedDescription)"
        }
    }

    private func replaceCueLibraryFromJSON() {
        let raw = cueTransportJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            copilotStatus = "Paste JSON into the cue editor first."
            return
        }
        guard let data = raw.data(using: .utf8) else { return }
        do {
            var doc = try JSONDecoder().decode(LightingCueDocument.self, from: data)
            doc.version = LightingCueDocument.currentVersion
            if doc.cues.isEmpty {
                doc.activeCueIndex = nil
            } else if let i = doc.activeCueIndex, !doc.cues.indices.contains(i) {
                doc.activeCueIndex = 0
            }
            appModel.applyLightingCueDocument(doc)
            selectedCueID = doc.activeCueIndex.flatMap { idx in
                doc.cues.indices.contains(idx) ? doc.cues[idx].id : nil
            }
            copilotStatus = "Replaced cue library with \(doc.cues.count) cue(s)."
        } catch {
            copilotStatus = "Replace decode failed (expect full LightingCueDocument JSON): \(error.localizedDescription)"
        }
    }

    private func exportSelectedProfileJSONToClipboard() {
        guard let pid = selectedProfileID,
              let profile = appModel.dmxPatchDocument.profile(id: pid)
        else {
            copilotStatus = "Select a fixture profile in the library to export."
            return
        }
        guard let str = Self.prettyJSONString(profile) else {
            copilotStatus = "Profile encode failed."
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(str, forType: .string)
        profileTransportJSON = str
        copilotStatus = "Copied selected profile JSON to clipboard."
    }

    private func pasteProfileFromClipboard() {
        guard let str = NSPasteboard.general.string(forType: .string), !str.isEmpty else {
            copilotStatus = "Clipboard is empty."
            return
        }
        profileTransportJSON = str
        copilotStatus = "Pasted into profile JSON editor."
    }

    private func importProfileFromTransportJSON() {
        let raw = profileTransportJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            copilotStatus = "Paste JSON into the profile editor first."
            return
        }
        guard let data = raw.data(using: .utf8) else { return }
        do {
            let decoded = try JSONDecoder().decode(FixtureProfile.self, from: data)
            let newName = decoded.name.hasSuffix(" (imported)") ? decoded.name : decoded.name + " (imported)"
            let profile = FixtureProfile(id: UUID(), name: newName, channels: decoded.channels)
            var patch = appModel.dmxPatchDocument
            patch.profiles.append(profile)
            selectedProfileID = profile.id
            appModel.applyDMXPatchDocument(patch)
            copilotStatus = "Imported profile \"\(profile.name)\"."
        } catch {
            copilotStatus = "Profile JSON decode failed: \(error.localizedDescription)"
        }
    }

    private func exportModulationJSONToClipboard() {
        let doc = appModel.modulationDocument
        guard let str = Self.prettyJSONString(doc) else {
            copilotStatus = "Modulation encode failed."
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(str, forType: .string)
        modulationTransportJSON = str
        copilotStatus = "Copied modulation document (\(doc.modulators.count) modulators)."
    }

    private func pasteModulationFromClipboard() {
        guard let str = NSPasteboard.general.string(forType: .string), !str.isEmpty else {
            copilotStatus = "Clipboard is empty."
            return
        }
        modulationTransportJSON = str
        copilotStatus = "Pasted into modulation JSON editor."
    }

    private func replaceModulationFromTransportJSON() {
        let raw = modulationTransportJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            copilotStatus = "Paste modulation JSON first."
            return
        }
        guard let data = raw.data(using: .utf8) else { return }
        do {
            var doc = try JSONDecoder().decode(ModulationDocument.self, from: data)
            doc.version = ModulationDocument.currentVersion
            appModel.applyModulationDocument(doc)
            copilotStatus = "Replaced modulation with \(doc.modulators.count) modulator(s)."
        } catch {
            copilotStatus = "Modulation JSON decode failed: \(error.localizedDescription)"
        }
    }
}
