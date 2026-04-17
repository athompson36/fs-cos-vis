import AppKit
import CoreGraphics
import Foundation

/// How the main-window Metal previews (Live Show, Scene Studio) are letterboxed to match output or a chosen frame.
enum PreviewAspectRatioSelection: String, Codable, CaseIterable, Identifiable, Equatable, Sendable {
    /// Match the fullscreen presentation rectangle on the selected **Output screen** (external backdrop).
    case auto = "auto"
    /// Match the main application window’s content aspect (updates when the window is resized).
    case applicationWindow = "application_window"
    case ratio16_9 = "16:9"
    case ratio4_3 = "4:3"
    case ratio16_10 = "16:10"
    case ratio21_9 = "21:9"
    case ratio3_2 = "3:2"
    case ratio239_1 = "2.39:1"
    case ratio1_1 = "1:1"

    var id: String { rawValue }

    var pickerLabel: String {
        switch self {
        case .auto: return "Auto"
        case .applicationWindow: return "Application window"
        case .ratio16_9: return "16∶9"
        case .ratio4_3: return "4∶3"
        case .ratio16_10: return "16∶10"
        case .ratio21_9: return "21∶9"
        case .ratio3_2: return "3∶2"
        case .ratio239_1: return "2.39∶1 (scope)"
        case .ratio1_1: return "1∶1"
        }
    }

    /// Width ÷ height for letterboxing the preview.
    func resolvedAspect(externalScreenIndex: Int) -> CGFloat {
        switch self {
        case .auto:
            return ExternalDisplayRouter.performanceAspectRatio(screenIndex: externalScreenIndex)
        case .applicationWindow:
            return Self.applicationWindowContentAspectRatio()
        case .ratio16_9:
            return 16 / 9
        case .ratio4_3:
            return 4 / 3
        case .ratio16_10:
            return 16 / 10
        case .ratio21_9:
            return 21 / 9
        case .ratio3_2:
            return 3 / 2
        case .ratio239_1:
            return 2.39
        case .ratio1_1:
            return 1
        }
    }

    private static func applicationWindowContentAspectRatio() -> CGFloat {
        guard let win = NSApp.mainWindow ?? NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }),
              let view = win.contentView
        else {
            return 16 / 9
        }
        let s = view.bounds.size
        let w = max(s.width, 1)
        let h = max(s.height, 1)
        return w / h
    }

    /// Largest size that fits `container` while preserving `aspect` (width ÷ height).
    static func aspectFitSize(container: CGSize, aspect: CGFloat) -> CGSize {
        let cw = max(container.width, 1)
        let ch = max(container.height, 1)
        guard aspect > 0 else { return CGSize(width: cw, height: ch) }
        let containerAspect = cw / ch
        if containerAspect > aspect {
            let h = ch
            let w = h * aspect
            return CGSize(width: w, height: h)
        } else {
            let w = cw
            let h = w / aspect
            return CGSize(width: w, height: h)
        }
    }
}

extension PreviewAspectRatioSelection {
    /// Longest edge (pixels) for the Syphon/OBS offscreen render target.
    static var obsStreamMaxLongEdge: CGFloat { 1920 }

    func obsStreamDrawableSize(externalScreenIndex: Int) -> CGSize {
        let aspect = resolvedAspect(externalScreenIndex: externalScreenIndex)
        let maxLong = Self.obsStreamMaxLongEdge
        if aspect >= 1 {
            let w = maxLong
            let h = max(1, (w / aspect).rounded())
            return CGSize(width: w, height: h)
        } else {
            let h = maxLong
            let w = max(1, (h * aspect).rounded())
            return CGSize(width: w, height: h)
        }
    }
}

/// User-controlled remote / hardware I/O settings (persisted).
struct RemoteControlSettings: Equatable {
    var remoteControlEnabled: Bool = false
    var remoteControlPort: Int = 8765
    /// When false, HTTP server binds to loopback only.
    var bindLAN: Bool = false
    var authToken: String = ""
    var midiInputUID: String = ""
    var dmxSerialDevicePath: String = ""
    var dmxOutputEnabled: Bool = false
    /// Letterboxing for Live Show / Scene Studio Metal previews.
    var previewAspectRatioSelection: PreviewAspectRatioSelection = .auto

    /// Publish a Syphon stream for OBS (**Syphon Client** source). Independent from on-screen preview aspect.
    var obsSyphonStreamEnabled: Bool = false
    /// Auto = match **Presentation display** output; Application window = main window content; or a fixed ratio.
    var obsStreamAspectRatioSelection: PreviewAspectRatioSelection = .auto
}

extension RemoteControlSettings: Codable {
    private enum CodingKeys: String, CodingKey {
        case remoteControlEnabled
        case remoteControlPort
        case bindLAN
        case authToken
        case midiInputUID
        case dmxSerialDevicePath
        case dmxOutputEnabled
        case previewAspectRatioSelection
        case obsSyphonStreamEnabled
        case obsStreamAspectRatioSelection
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        remoteControlEnabled = try c.decodeIfPresent(Bool.self, forKey: .remoteControlEnabled) ?? false
        remoteControlPort = try c.decodeIfPresent(Int.self, forKey: .remoteControlPort) ?? 8765
        bindLAN = try c.decodeIfPresent(Bool.self, forKey: .bindLAN) ?? false
        authToken = try c.decodeIfPresent(String.self, forKey: .authToken) ?? ""
        midiInputUID = try c.decodeIfPresent(String.self, forKey: .midiInputUID) ?? ""
        dmxSerialDevicePath = try c.decodeIfPresent(String.self, forKey: .dmxSerialDevicePath) ?? ""
        dmxOutputEnabled = try c.decodeIfPresent(Bool.self, forKey: .dmxOutputEnabled) ?? false
        previewAspectRatioSelection = try c.decodeIfPresent(PreviewAspectRatioSelection.self, forKey: .previewAspectRatioSelection) ?? .auto
        obsSyphonStreamEnabled = try c.decodeIfPresent(Bool.self, forKey: .obsSyphonStreamEnabled) ?? false
        obsStreamAspectRatioSelection = try c.decodeIfPresent(PreviewAspectRatioSelection.self, forKey: .obsStreamAspectRatioSelection) ?? .auto
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(remoteControlEnabled, forKey: .remoteControlEnabled)
        try c.encode(remoteControlPort, forKey: .remoteControlPort)
        try c.encode(bindLAN, forKey: .bindLAN)
        try c.encode(authToken, forKey: .authToken)
        try c.encode(midiInputUID, forKey: .midiInputUID)
        try c.encode(dmxSerialDevicePath, forKey: .dmxSerialDevicePath)
        try c.encode(dmxOutputEnabled, forKey: .dmxOutputEnabled)
        try c.encode(previewAspectRatioSelection, forKey: .previewAspectRatioSelection)
        try c.encode(obsSyphonStreamEnabled, forKey: .obsSyphonStreamEnabled)
        try c.encode(obsStreamAspectRatioSelection, forKey: .obsStreamAspectRatioSelection)
    }
}

enum RemoteControlSettingsStore {
    private static let key = "CosmicVisualizer.RemoteControlSettings.v1"

    static func load() -> RemoteControlSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(RemoteControlSettings.self, from: data)
        else {
            return RemoteControlSettings()
        }
        return s
    }

    static func save(_ settings: RemoteControlSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
