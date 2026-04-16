import XCTest
@testable import CosmicVisualizer

final class BPMDetectorTests: XCTestCase {
    func testSyntheticPulseTrain_approximately120BPM() {
        var time: TimeInterval = 0
        let detector = BPMDetector { time }

        // 50 ms steps; spike every 10 steps => 0.5 s between onsets => 120 BPM
        for step in 0..<400 {
            time = Double(step) * 0.05
            let spike = step % 10 == 0
            let flux: Float = spike ? 80 : 0.02
            _ = detector.ingest(spectralFlux: flux)
        }

        let result = detector.ingest(spectralFlux: 0.02)
        XCTAssertGreaterThan(result.bpm, 110)
        XCTAssertLessThan(result.bpm, 135)
        XCTAssertGreaterThan(result.confidence, 0.2)
    }

    func testReset_clearsState() {
        var time: TimeInterval = 0
        let detector = BPMDetector { time }
        time = 0
        _ = detector.ingest(spectralFlux: 100)
        time = 0.5
        _ = detector.ingest(spectralFlux: 100)
        detector.reset()
        let r = detector.ingest(spectralFlux: 1)
        XCTAssertEqual(r.bpm, 0)
        XCTAssertEqual(r.confidence, 0)
    }
}
