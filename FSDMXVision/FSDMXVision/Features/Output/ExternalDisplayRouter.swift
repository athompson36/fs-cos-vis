import AppKit

/// Helpers for routing fullscreen or multi-window output to non-main displays.
enum ExternalDisplayRouter {
    static var screens: [NSScreen] {
        NSScreen.screens
    }

    static var secondaryScreens: [NSScreen] {
        screens.filter { $0 != NSScreen.main }
    }

    /// Frame in global coordinates suitable for a borderless performance window on a given screen.
    static func performanceFrame(on screen: NSScreen) -> CGRect {
        screen.frame
    }

    /// Width ÷ height of `performanceFrame` for the screen at `screenIndex` (same shape as fullscreen video output on that display).
    /// Falls back to the main screen, then the first listed screen, then 16∶9 if none exist.
    static func performanceAspectRatio(screenIndex: Int) -> CGFloat {
        let list = screens
        let screen: NSScreen?
        if list.indices.contains(screenIndex) {
            screen = list[screenIndex]
        } else {
            screen = NSScreen.main ?? list.first
        }
        guard let s = screen else { return 16 / 9 }
        let f = s.frame
        return f.width / max(f.height, 1)
    }

    /// Human-readable label for pickers (includes resolution and main/external hint).
    static func displayName(for screen: NSScreen, index: Int) -> String {
        let frame = screen.frame
        let w = Int(frame.width.rounded())
        let h = Int(frame.height.rounded())
        let name = screen.localizedName
        let role = screen == NSScreen.main ? "Main / menu bar" : "External \(index)"
        return "\(name) — \(w)×\(h) (\(role))"
    }

    /// Index of the screen containing the center point of the given window, if any.
    static func screenIndexContaining(window: NSWindow?) -> Int? {
        guard let window else { return NSScreen.main.flatMap { main in screens.firstIndex(where: { $0 === main }) } }
        let center = CGPoint(x: window.frame.midX, y: window.frame.midY)
        for (i, screen) in screens.enumerated() where screen.frame.contains(center) {
            return i
        }
        return NSScreen.main.flatMap { main in screens.firstIndex(where: { $0 === main }) }
    }

    /// First non-main screen if present, otherwise `0` (single-display setups).
    static func defaultPreferredScreenIndex() -> Int {
        let list = screens
        guard !list.isEmpty else { return 0 }
        guard let main = NSScreen.main else { return 0 }
        if let idx = list.firstIndex(where: { $0 !== main }) {
            return idx
        }
        return 0
    }
}
