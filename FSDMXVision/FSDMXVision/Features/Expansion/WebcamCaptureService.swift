import AVFoundation
import CoreMedia
import Foundation
import SwiftUI

/// Live camera frames for calibration sweeps (macOS).
final class WebcamCaptureService: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.fsdmxvision.webcam")
    private let output = AVCaptureVideoDataOutput()
    private(set) var isRunning = false

    /// Latest frame luma sample (0…1), updated from the video queue; poll from main during calibration.
    nonisolated(unsafe) private(set) var latestSampleLuma: Double = 0

    static func availableVideoDevices() -> [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.continuityCamera, .externalUnknown, .builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        ).devices
    }

    func startIfAuthorized(preferredDeviceUniqueID: String? = nil) async throws {
        guard !isRunning else { return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            let ok = await Self.requestVideoAccess()
            guard ok else { throw WebcamError.permissionDenied }
        default:
            throw WebcamError.permissionDenied
        }
        session.beginConfiguration()
        session.sessionPreset = .medium
        let device: AVCaptureDevice? = {
            if let preferredDeviceUniqueID,
               let matched = Self.availableVideoDevices().first(where: { $0.uniqueID == preferredDeviceUniqueID }) {
                return matched
            }
            return AVCaptureDevice.default(for: .video)
        }()
        guard let device else {
            session.commitConfiguration()
            throw WebcamError.noDevice
        }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw WebcamError.cannotAddInput
        }
        session.addInput(input)
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            throw WebcamError.cannotAddOutput
        }
        session.addOutput(output)
        output.setSampleBufferDelegate(self, queue: queue)
        session.commitConfiguration()
        session.startRunning()
        isRunning = true
    }

    private static func requestVideoAccess() async -> Bool {
        await withCheckedContinuation { cont in
            AVCaptureDevice.requestAccess(for: .video) { cont.resume(returning: $0) }
        }
    }

    func stop() {
        guard isRunning else { return }
        session.stopRunning()
        isRunning = false
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buf = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        CVPixelBufferLockBaseAddress(buf, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buf, .readOnly) }
        let w = CVPixelBufferGetWidth(buf)
        let h = CVPixelBufferGetHeight(buf)
        guard w > 0, h > 0,
              let base = CVPixelBufferGetBaseAddress(buf)
        else { return }
        let rowBytes = CVPixelBufferGetBytesPerRow(buf)
        // Downsample: stride 16px for speed
        var sum: Double = 0
        var count: Double = 0
        for y in stride(from: 0, to: h, by: 16) {
            let row = base.advanced(by: y * rowBytes)
            for x in stride(from: 0, to: w, by: 16) {
                let p = row.load(fromByteOffset: x * 4, as: UInt32.self)
                let b = Double(p & 0xFF)
                let g = Double((p >> 8) & 0xFF)
                let r = Double((p >> 16) & 0xFF)
                sum += (r + g + b) / 3.0
                count += 1
            }
        }
        let luma = count > 0 ? sum / count / 255.0 : 0
        latestSampleLuma = luma
    }
}

enum WebcamError: Error {
    case permissionDenied
    case noDevice
    case cannotAddInput
    case cannotAddOutput
}
