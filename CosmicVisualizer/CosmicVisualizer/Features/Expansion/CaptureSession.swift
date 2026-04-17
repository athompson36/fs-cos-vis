import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import Foundation

final class CaptureSession: NSObject {
    struct RecordingQuality: Equatable, Sendable {
        var framesPerSecond: Int
        var videoBitrate: Int

        static let standard = RecordingQuality(framesPerSecond: 30, videoBitrate: 8_000_000)
    }

    enum CaptureError: LocalizedError {
        case alreadyRecording
        case writerSetupFailed
        case invalidWindow
        case audioSetupFailed(String)
        case noFirstFrame

        var errorDescription: String? {
            switch self {
            case .alreadyRecording: "Recording is already in progress."
            case .writerSetupFailed: "Could not configure the recording writer."
            case .invalidWindow: "Could not capture the selected window."
            case .audioSetupFailed(let reason): "Audio setup failed: \(reason)"
            case .noFirstFrame: "Could not sample an initial frame from the selected output."
            }
        }
    }

    private(set) var isRecording = false
    private(set) var startedAt: Date?
    private(set) var outputURL: URL?
    private(set) var audioDiagnosticMessage = "Audio source not initialized."

    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var audioInput: AVAssetWriterInput?
    private var captureTimer: DispatchSourceTimer?
    private var audioCaptureSession: AVCaptureSession?
    private var recordingQueue = DispatchQueue(label: "CaptureSession.recording.queue")
    private var frameInterval: TimeInterval = 1.0 / 30.0

    func begin(
        windowNumber: CGWindowID,
        outputURL: URL,
        preferredAudioDeviceName: String?,
        quality: RecordingQuality = .standard
    ) throws {
        guard !isRecording else { throw CaptureError.alreadyRecording }
        guard let firstFrame = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowNumber,
            [.boundsIgnoreFraming, .bestResolution]
        ) else {
            throw CaptureError.noFirstFrame
        }
        let width = max(2, firstFrame.width)
        let height = max(2, firstFrame.height)

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
        let clampedFPS = max(12, min(60, quality.framesPerSecond))
        let clampedBitrate = max(1_000_000, min(25_000_000, quality.videoBitrate))
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: clampedBitrate,
                AVVideoExpectedSourceFrameRateKey: clampedFPS,
            ],
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
            ]
        )
        guard writer.canAdd(videoInput) else { throw CaptureError.writerSetupFailed }
        writer.add(videoInput)

        let audioInput = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 2,
                AVSampleRateKey: 44_100,
                AVEncoderBitRateKey: 128_000,
            ]
        )
        audioInput.expectsMediaDataInRealTime = true
        if writer.canAdd(audioInput) {
            writer.add(audioInput)
            self.audioInput = audioInput
        } else {
            self.audioInput = nil
        }

        guard writer.startWriting() else { throw CaptureError.writerSetupFailed }
        writer.startSession(atSourceTime: .zero)

        self.writer = writer
        self.videoInput = videoInput
        pixelAdaptor = adaptor
        self.outputURL = outputURL
        startedAt = Date()
        isRecording = true
        frameInterval = 1.0 / Double(clampedFPS)
        audioDiagnosticMessage = "Initializing audio source…"

        try startAudioCapture(preferredAudioDeviceName: preferredAudioDeviceName)
        startWindowPolling(windowNumber: windowNumber)
    }

    func end() async {
        guard isRecording else { return }
        isRecording = false
        captureTimer?.cancel()
        captureTimer = nil
        audioCaptureSession?.stopRunning()
        audioCaptureSession = nil
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()
        await withCheckedContinuation { cont in
            writer?.finishWriting {
                cont.resume()
            }
        }
        writer = nil
        videoInput = nil
        pixelAdaptor = nil
        startedAt = nil
    }

    private func startWindowPolling(windowNumber: CGWindowID) {
        let timer = DispatchSource.makeTimerSource(queue: recordingQueue)
        let frameStep = Int(frameInterval * 1_000_000_000)
        timer.schedule(deadline: .now(), repeating: .nanoseconds(max(1, frameStep)))
        timer.setEventHandler { [weak self] in
            self?.appendWindowFrame(windowNumber: windowNumber)
        }
        captureTimer = timer
        timer.resume()
    }

    private func appendWindowFrame(windowNumber: CGWindowID) {
        guard isRecording,
              let image = CGWindowListCreateImage(
                  .null,
                  .optionIncludingWindow,
                  windowNumber,
                  [.boundsIgnoreFraming, .bestResolution]
              ),
              let adaptor = pixelAdaptor,
              let input = videoInput,
              input.isReadyForMoreMediaData,
              let pool = adaptor.pixelBufferPool
        else { return }

        var pixelBufferOut: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBufferOut) == kCVReturnSuccess,
              let pixelBuffer = pixelBufferOut
        else { return }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: CVPixelBufferGetWidth(pixelBuffer),
            height: CVPixelBufferGetHeight(pixelBuffer),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer)))

        let elapsed = Date().timeIntervalSince(startedAt ?? Date())
        let pts = CMTime(seconds: elapsed, preferredTimescale: 600)
        adaptor.append(pixelBuffer, withPresentationTime: pts)
    }

    private func startAudioCapture(preferredAudioDeviceName: String?) throws {
        guard audioInput != nil else { return }
        let session = AVCaptureSession()
        session.beginConfiguration()
        let (device, diagnostic) = chooseAudioDevice(preferredAudioDeviceName: preferredAudioDeviceName)
        audioDiagnosticMessage = diagnostic
        guard let device else {
            session.commitConfiguration()
            audioDiagnosticMessage = "Audio input unavailable: no capture device found."
            return
        }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            throw CaptureError.audioSetupFailed("Input cannot be added")
        }
        session.addInput(input)
        let output = AVCaptureAudioDataOutput()
        output.setSampleBufferDelegate(self, queue: recordingQueue)
        guard session.canAddOutput(output) else {
            throw CaptureError.audioSetupFailed("Output cannot be added")
        }
        session.addOutput(output)
        session.commitConfiguration()
        audioCaptureSession = session
        session.startRunning()
    }

    private func chooseAudioDevice(preferredAudioDeviceName: String?) -> (AVCaptureDevice?, String) {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone, .externalUnknown],
            mediaType: .audio,
            position: .unspecified
        )
        guard !discovery.devices.isEmpty else {
            return (nil, "Audio input unavailable: no capture device found.")
        }
        if let preferredAudioDeviceName {
            if let matched = discovery.devices.first(where: { $0.localizedName == preferredAudioDeviceName }) {
                return (matched, "Audio source: \(matched.localizedName)")
            }
            let fallback = discovery.devices.first
            if let fallback {
                return (fallback, "Preferred audio source unavailable; using \(fallback.localizedName).")
            }
        }
        if let first = discovery.devices.first {
            return (first, "Audio source: \(first.localizedName)")
        }
        return (nil, "Audio input unavailable: no capture device found.")
    }
}

extension CaptureSession: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard isRecording,
              let audioInput,
              audioInput.isReadyForMoreMediaData
        else { return }
        audioInput.append(sampleBuffer)
    }
}
