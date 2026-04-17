import CoreAudio
import Foundation

/// Lists macOS audio input devices and resolves human-readable names.
enum AudioDeviceEnumerator {
    struct Device: Identifiable, Equatable, Sendable {
        let id: AudioDeviceID
        let name: String
        let uid: String
        let inputChannelCount: Int
        let outputChannelCount: Int
    }

    static func inputDevices() -> [Device] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )
        guard status == noErr else { return [] }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )
        guard status == noErr else { return [] }

        return deviceIDs.compactMap { deviceID in
            guard hasInputStream(deviceID: deviceID) else { return nil }
            let name = deviceName(deviceID: deviceID) ?? "Input \(deviceID)"
            let uid = deviceUID(deviceID: deviceID) ?? "\(deviceID)"
            return Device(
                id: deviceID,
                name: name,
                uid: uid,
                inputChannelCount: channelCount(deviceID: deviceID, scope: kAudioDevicePropertyScopeInput),
                outputChannelCount: channelCount(deviceID: deviceID, scope: kAudioDevicePropertyScopeOutput)
            )
        }
    }

    static func outputDevices() -> [Device] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )
        guard status == noErr else { return [] }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )
        guard status == noErr else { return [] }

        return deviceIDs.compactMap { deviceID in
            let outChannels = channelCount(deviceID: deviceID, scope: kAudioDevicePropertyScopeOutput)
            guard outChannels > 0 else { return nil }
            let name = deviceName(deviceID: deviceID) ?? "Output \(deviceID)"
            let uid = deviceUID(deviceID: deviceID) ?? "\(deviceID)"
            return Device(
                id: deviceID,
                name: name,
                uid: uid,
                inputChannelCount: channelCount(deviceID: deviceID, scope: kAudioDevicePropertyScopeInput),
                outputChannelCount: outChannels
            )
        }
    }

    /// Creates an aggregate input device that OBS can read (selected input + optional virtual loopback).
    /// Returns the created CoreAudio device UID when successful.
    static func createOBSAggregateInputDevice(
        inputDeviceUID: String,
        preferredLoopbackUID: String? = nil
    ) throws -> String {
        let aggregateUID = "com.cosmicvisualizer.obs-forward.\(UUID().uuidString.lowercased())"
        let subDeviceUIDKey = kAudioSubDeviceUIDKey as CFString
        var subDevices: [[CFString: String]] = [[subDeviceUIDKey: inputDeviceUID]]
        if let loopUID = preferredLoopbackUID, !loopUID.isEmpty {
            subDevices.append([subDeviceUIDKey: loopUID])
        }
        let aggregateNameKey = kAudioAggregateDeviceNameKey as CFString
        let aggregateUIDKey = kAudioAggregateDeviceUIDKey as CFString
        let aggregateSubListKey = kAudioAggregateDeviceSubDeviceListKey as CFString
        let aggregateMainSubKey = kAudioAggregateDeviceMainSubDeviceKey as CFString
        let aggregatePrivateKey = kAudioAggregateDeviceIsPrivateKey as CFString
        let description: [CFString: Any] = [
            aggregateNameKey: "Cosmic Visualizer OBS Forward",
            aggregateUIDKey: aggregateUID,
            aggregateSubListKey: subDevices,
            aggregateMainSubKey: inputDeviceUID,
            aggregatePrivateKey: false,
        ]

        var createdDeviceID = AudioDeviceID()
        let status = AudioHardwareCreateAggregateDevice(description as CFDictionary, &createdDeviceID)
        guard status == noErr else {
            throw NSError(
                domain: "AudioDeviceEnumerator",
                code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "Could not create OBS aggregate device (\(status))."]
            )
        }
        return aggregateUID
    }

    static func defaultInputDeviceID() -> AudioDeviceID? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID()
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceID
        )
        return status == noErr ? deviceID : nil
    }

    private static func hasInputStream(deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        var propertySize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &propertySize) == noErr,
              propertySize > 0
        else { return false }

        let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
        defer { bufferListPointer.deallocate() }

        guard AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &propertySize, bufferListPointer) == noErr else {
            return false
        }

        let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPointer)
        return bufferList.contains { $0.mNumberChannels > 0 }
    }

    private static func deviceName(deviceID: AudioDeviceID) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var name = [CChar](repeating: 0, count: 256)
        var dataSize = UInt32(name.count)
        let status = name.withUnsafeMutableBytes { ptr -> OSStatus in
            guard let base = ptr.baseAddress else { return -1 }
            return AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, base)
        }
        guard status == noErr else { return nil }
        return String(cString: name)
    }

    private static func deviceUID(deviceID: AudioDeviceID) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var cf: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &cf
        )
        guard status == noErr else { return nil }
        return cf?.takeRetainedValue() as String?
    }

    private static func channelCount(deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Int {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var propertySize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &propertySize) == noErr,
              propertySize > 0
        else { return 0 }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(propertySize), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &propertySize, raw) == noErr else {
            return 0
        }
        let abl = raw.bindMemory(to: AudioBufferList.self, capacity: 1)
        let list = UnsafeMutableAudioBufferListPointer(abl)
        return list.reduce(0) { $0 + Int($1.mNumberChannels) }
    }
}
