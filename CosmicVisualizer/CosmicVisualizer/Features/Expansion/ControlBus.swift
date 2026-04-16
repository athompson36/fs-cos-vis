import Foundation

/// Future-facing control surface (MIDI, OSC, DMX). Stubs keep wiring testable without hardware.
protocol ControlBus: AnyObject {
    var isRunning: Bool { get }
    func start()
    func stop()
}

final class MIDIControlBusStub: ControlBus {
    private(set) var isRunning = false

    func start() {
        isRunning = true
    }

    func stop() {
        isRunning = false
    }
}

final class OSCControlBusStub: ControlBus {
    private(set) var isRunning = false

    func start() {
        isRunning = true
    }

    func stop() {
        isRunning = false
    }

    /// Parses `/cosmic/bpm f 128.5` style messages (whitespace-separated).
    static func parseSimpleMessage(_ line: String) -> (address: String, floatValue: Float)? {
        let parts = line.split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count >= 3, parts[1] == "f", let value = Float(parts[2]) else { return nil }
        let addr = parts[0]
        guard addr.hasPrefix("/") else { return nil }
        return (addr, value)
    }
}

/// Placeholder for DMX channel mapping — no I/O yet.
final class DMXControlStub: ControlBus {
    private(set) var isRunning = false

    func start() { isRunning = true }
    func stop() { isRunning = false }

    static func clampChannel(_ v: Float) -> UInt8 {
        UInt8(max(0, min(255, v)))
    }
}
