import Foundation

enum FixtureVerificationService {
    static func sampleLuma(webcam: WebcamCaptureService, seconds: TimeInterval) async -> Double {
        let duration = max(0.15, seconds)
        let sampleCount = 4
        var sum: Double = 0
        for _ in 0 ..< sampleCount {
            if Task.isCancelled { break }
            try? await Task.sleep(nanoseconds: UInt64((duration / Double(sampleCount)) * 1_000_000_000))
            sum += webcam.latestSampleLuma
        }
        return sum / Double(sampleCount)
    }

    static func bestProbeChannel(profile: FixtureProfile) -> Int {
        let preferred: [FixtureChannelRole] = [.intensity, .white, .red, .green, .blue, .hazeOutput]
        for role in preferred {
            if let idx = profile.channels.firstIndex(where: { $0.role == role }) {
                return idx
            }
        }
        return 0
    }

    static func persist(report: FixtureVerificationDocument, outputFolder: URL) {
        let ctx = outputFolder.appendingPathComponent("context", isDirectory: true)
        try? FileManager.default.createDirectory(at: ctx, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(report) {
            try? data.write(to: ctx.appendingPathComponent("fixture_verification.json"), options: .atomic)
        }
    }
}
