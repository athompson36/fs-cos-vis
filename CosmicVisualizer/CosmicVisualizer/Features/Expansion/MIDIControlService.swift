import CoreMIDI
import Foundation

/// Core MIDI input: clock / transport + control changes for `RemoteControlCommand` mapping.
final class MIDIControlService: ControlBus {
    private var client = MIDIClientRef()
    private var inputPort = MIDIPortRef()
    private(set) var isRunning = false

    var filterSourceUID: Int32 = 0

    var onClockTick: () -> Void = {}
    var onTransportStart: () -> Void = {}
    var onTransportStop: () -> Void = {}
    var onTransportContinue: () -> Void = {}
    var onControlChange: (_ channel: Int, _ controller: Int, _ value: Int) -> Void = { _, _, _ in }

    func start() {
        guard !isRunning else { return }
        var status = MIDIClientCreateWithBlock("CosmicVisualizer MIDI" as CFString, &client) { _ in }
        guard status == noErr else { return }

        status = MIDIInputPortCreateWithBlock(client, "Control In" as CFString, &inputPort) { [weak self] packetList, _ in
            self?.handle(packetList: packetList)
        }
        guard status == noErr else {
            MIDIClientDispose(client)
            client = MIDIClientRef()
            return
        }

        let sourceCount = MIDIGetNumberOfSources()
        for i in 0..<sourceCount {
            let src = MIDIGetSource(i)
            if filterSourceUID != 0 {
                var uid: Int32 = 0
                guard MIDIObjectGetIntegerProperty(src, kMIDIPropertyUniqueID, &uid) == noErr,
                      uid == filterSourceUID
                else { continue }
            }
            MIDIPortConnectSource(inputPort, src, nil)
        }

        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        if inputPort != 0 {
            MIDIPortDispose(inputPort)
            inputPort = 0
        }
        if client != 0 {
            MIDIClientDispose(client)
            client = 0
        }
        isRunning = false
    }

    private func handle(packetList: UnsafePointer<MIDIPacketList>) {
        let list = packetList.pointee
        let count = Int(list.numPackets)
        var packet = list.packet
        for idx in 0..<count {
            let current = packet
            let len = Int(current.length)
            var bytes = [UInt8](repeating: 0, count: len)
            withUnsafeBytes(of: current.data) { raw in
                guard let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                for i in 0..<len { bytes[i] = base[i] }
            }
            parse(bytes: bytes)
            guard idx + 1 < count else { break }
            var anchor = current
            packet = withUnsafePointer(to: &anchor) { MIDIPacketNext($0).pointee }
        }
    }

    private func parse(bytes: [UInt8]) {
        var i = 0
        while i < bytes.count {
            let status = bytes[i]
            switch status {
            case 0xF8:
                onClockTick()
                i += 1
            case 0xFA:
                onTransportStart()
                i += 1
            case 0xFC:
                onTransportStop()
                i += 1
            case 0xFB:
                onTransportContinue()
                i += 1
            default:
                if (status & 0xF0) == 0xB0, i + 2 < bytes.count {
                    let ch = Int(status & 0x0F)
                    let cc = Int(bytes[i + 1])
                    let v = Int(bytes[i + 2])
                    onControlChange(ch, cc, v)
                    i += 3
                } else {
                    i += 1
                }
            }
        }
    }
}
