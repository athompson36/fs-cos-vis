import Foundation

/// Hook for future frame/audio export — no AVFoundation wiring in this milestone.
final class CaptureSession {
    private(set) var isRecording = false

    func begin() {
        isRecording = true
    }

    func end() {
        isRecording = false
    }
}
