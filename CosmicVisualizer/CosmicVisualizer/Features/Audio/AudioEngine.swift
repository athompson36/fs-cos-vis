import AudioToolbox
import AVFoundation
import Combine
import Foundation

/// Captures default or selected macOS input, computes FFT features, and updates BPM.
final class AudioEngine: ObservableObject, @unchecked Sendable {
    enum InputChannelSelection: Equatable, Sendable {
        case stereoPair(startIndex: Int)
        case mono(index: Int)
        case mixAll
    }

    @Published private(set) var features = AudioFeatures()
    @Published private(set) var availableInputDevices: [AudioDeviceEnumerator.Device] = []
    @Published private(set) var availableOutputDevices: [AudioDeviceEnumerator.Device] = []
    @Published var selectedInputDeviceID: AudioDeviceID? {
        didSet {
            guard oldValue != selectedInputDeviceID else { return }
            try? restartIfRunning()
        }
    }
    /// Defaults to stereo channels 1/2 on startup where available.
    @Published var selectedInputChannelSelection: InputChannelSelection = .stereoPair(startIndex: 0)
    @Published var obsAudioForwardEnabled: Bool = false {
        didSet {
            guard oldValue != obsAudioForwardEnabled else { return }
            try? restartIfRunning()
        }
    }
    @Published var selectedOutputDeviceID: AudioDeviceID? {
        didSet {
            guard oldValue != selectedOutputDeviceID else { return }
            try? restartIfRunning()
        }
    }

    private let engine = AVAudioEngine()
    private let bpmDetector = BPMDetector()
    private let fftSize = 1024
    private let hopSize = 512
    private lazy var window: [Float] = AudioFeatureExtractor.hannWindow(length: fftSize)

    private var fftAccumulator: [Float] = []
    private var previousMagnitudes: [Float]?
    private var isRunning = false

    /// Last FFT-derived values (read on audio thread only; copied into `features` on publish).
    private var lastLow: Float = 0
    private var lastMid: Float = 0
    private var lastHigh: Float = 0
    private var lastFlux: Float = 0
    private var lastBPM: Float = 0
    private var lastConfidence: Float = 0

    init() {
        refreshDevices()
        selectedInputDeviceID = nil
    }

    func refreshDevices() {
        availableInputDevices = AudioDeviceEnumerator.inputDevices()
        availableOutputDevices = AudioDeviceEnumerator.outputDevices()
        if let selected = selectedInputDeviceID,
           !availableInputDevices.contains(where: { $0.id == selected }) {
            selectedInputDeviceID = AudioDeviceEnumerator.defaultInputDeviceID()
        }
        if let selectedOut = selectedOutputDeviceID,
           !availableOutputDevices.contains(where: { $0.id == selectedOut }) {
            selectedOutputDeviceID = nil
        }
        normalizeInputChannelSelectionForCurrentDevice()
    }

    func start() throws {
        guard !isRunning else { return }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        try applySelectedInputDevice()
        try configureOBSForwardIfEnabled(inputFormat: format)

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: AVAudioFrameCount(hopSize), format: format) { [weak self] buffer, _ in
            self?.handle(buffer: buffer)
        }

        try engine.start()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.mainMixerNode.outputVolume = 1
        engine.stop()
        isRunning = false
        fftAccumulator.removeAll()
        previousMagnitudes = nil
        bpmDetector.reset()
        lastLow = 0
        lastMid = 0
        lastHigh = 0
        lastFlux = 0
        lastBPM = 0
        lastConfidence = 0
    }

    private func applySelectedInputDevice() throws {
        let deviceID = selectedInputDeviceID ?? AudioDeviceEnumerator.defaultInputDeviceID()
        guard let deviceID else {
            throw NSError(domain: "AudioEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "No input device"])
        }
        var id = deviceID
        guard let audioUnit = engine.inputNode.audioUnit else {
            throw NSError(domain: "AudioEngine", code: 2, userInfo: [NSLocalizedDescriptionKey: "Input audio unit unavailable"])
        }
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &id,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else {
            throw NSError(domain: "AudioEngine", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Could not set input device"])
        }
    }

    private func applySelectedOutputDevice() throws {
        guard let deviceID = selectedOutputDeviceID else { return }
        guard let audioUnit = engine.outputNode.audioUnit else {
            throw NSError(domain: "AudioEngine", code: 3, userInfo: [NSLocalizedDescriptionKey: "Output audio unit unavailable"])
        }
        var id = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &id,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else {
            throw NSError(domain: "AudioEngine", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Could not set output device"])
        }
    }

    private func configureOBSForwardIfEnabled(inputFormat: AVAudioFormat) throws {
        engine.disconnectNodeInput(engine.mainMixerNode)
        engine.mainMixerNode.outputVolume = obsAudioForwardEnabled ? 1 : 0
        guard obsAudioForwardEnabled else { return }
        try applySelectedOutputDevice()
        engine.connect(engine.inputNode, to: engine.mainMixerNode, format: inputFormat)
    }

    private func restartIfRunning() throws {
        if isRunning {
            stop()
            try start()
        } else {
            try applySelectedInputDevice()
            if obsAudioForwardEnabled {
                try applySelectedOutputDevice()
            }
        }
    }

    private func handle(buffer: AVAudioPCMBuffer) {
        guard let mono = analysisSamples(from: buffer), !mono.isEmpty else { return }

        let (rms, peak) = AudioFeatureExtractor.rmsAndPeak(samples: mono)
        fftAccumulator.append(contentsOf: mono)

        while fftAccumulator.count >= fftSize {
            let frame = Array(fftAccumulator.prefix(fftSize))
            fftAccumulator.removeFirst(hopSize)

            guard let mags = AudioFeatureExtractor.fftMagnitudes(samples: frame, window: window) else { continue }
            let bands = AudioFeatureExtractor.bandEnergies(magnitudes: mags)
            lastLow = bands.low
            lastMid = bands.mid
            lastHigh = bands.high

            let flux: Float
            if let previous = previousMagnitudes {
                flux = AudioFeatureExtractor.spectralFlux(previous: previous, current: mags)
            } else {
                flux = 0
            }
            previousMagnitudes = mags
            lastFlux = flux

            let bpmState = bpmDetector.ingest(spectralFlux: flux)
            lastBPM = Float(bpmState.bpm)
            lastConfidence = Float(bpmState.confidence)
        }

        var next = AudioFeatures()
        next.rms = rms
        next.peak = peak
        next.lowBandEnergy = lastLow
        next.midBandEnergy = lastMid
        next.highBandEnergy = lastHigh
        next.spectralFlux = lastFlux
        next.estimatedBPM = lastBPM
        next.beatConfidence = lastConfidence

        DispatchQueue.main.async { [weak self] in
            self?.features = next
        }
    }

    private func analysisSamples(from buffer: AVAudioPCMBuffer) -> [Float]? {
        switch selectedInputChannelSelection {
        case let .stereoPair(startIndex):
            if let samples = AudioFeatureExtractor.stereoPairMonoSamples(from: buffer, pairStartIndex: startIndex) {
                return samples
            }
            return AudioFeatureExtractor.monoFloatSamples(from: buffer)
        case let .mono(index):
            return AudioFeatureExtractor.monoFloatSamples(from: buffer, preferredChannelIndex: index)
        case .mixAll:
            return AudioFeatureExtractor.monoFloatSamples(from: buffer)
        }
    }

    private func normalizeInputChannelSelectionForCurrentDevice() {
        let channels = selectedInputDeviceID
            .flatMap { id in availableInputDevices.first(where: { $0.id == id })?.inputChannelCount }
            ?? availableInputDevices.first(where: { $0.id == AudioDeviceEnumerator.defaultInputDeviceID() })?.inputChannelCount
            ?? 0
        switch selectedInputChannelSelection {
        case let .stereoPair(start):
            if channels < 2 {
                selectedInputChannelSelection = .mixAll
            } else {
                let safeStart = max(0, min(start, channels - 2))
                // keep pair aligned to odd/even channel pair boundaries
                selectedInputChannelSelection = .stereoPair(startIndex: safeStart - (safeStart % 2))
            }
        case let .mono(index):
            if channels <= 0 {
                selectedInputChannelSelection = .mixAll
            } else {
                selectedInputChannelSelection = .mono(index: max(0, min(index, channels - 1)))
            }
        case .mixAll:
            if channels >= 2 {
                selectedInputChannelSelection = .stereoPair(startIndex: 0)
            }
        }
    }
}
