import AudioToolbox
import AVFoundation
import Combine
import Foundation

/// Captures default or selected macOS input, computes FFT features, and updates BPM.
final class AudioEngine: ObservableObject, @unchecked Sendable {
    @Published private(set) var features = AudioFeatures()
    @Published private(set) var availableInputDevices: [AudioDeviceEnumerator.Device] = []
    @Published var selectedInputDeviceID: AudioDeviceID? {
        didSet {
            guard oldValue != selectedInputDeviceID else { return }
            try? applySelectedDevice()
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
        selectedInputDeviceID = AudioDeviceEnumerator.defaultInputDeviceID()
    }

    func refreshDevices() {
        availableInputDevices = AudioDeviceEnumerator.inputDevices()
        if let selected = selectedInputDeviceID,
           !availableInputDevices.contains(where: { $0.id == selected }) {
            selectedInputDeviceID = AudioDeviceEnumerator.defaultInputDeviceID()
        }
    }

    func start() throws {
        guard !isRunning else { return }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        try applySelectedDevice()

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

    private func applySelectedDevice() throws {
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

    private func handle(buffer: AVAudioPCMBuffer) {
        guard let mono = AudioFeatureExtractor.monoFloatSamples(from: buffer), !mono.isEmpty else { return }

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
}
