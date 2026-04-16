import XCTest
@testable import CosmicVisualizer

final class AudioFeatureExtractorTests: XCTestCase {
    func testRmsAndPeak_constantSignal() {
        let samples = [Float](repeating: 0.25, count: 512)
        let (rms, peak) = AudioFeatureExtractor.rmsAndPeak(samples: samples)
        XCTAssertEqual(rms, 0.25, accuracy: 1e-4)
        XCTAssertEqual(peak, 0.25, accuracy: 1e-4)
    }

    func testRmsAndPeak_empty() {
        let (rms, peak) = AudioFeatureExtractor.rmsAndPeak(samples: [])
        XCTAssertEqual(rms, 0)
        XCTAssertEqual(peak, 0)
    }

    func testSpectralFlux_positiveDifference() {
        let prev = [Float](repeating: 1, count: 8)
        let cur = [Float](repeating: 2, count: 8)
        let flux = AudioFeatureExtractor.spectralFlux(previous: prev, current: cur)
        XCTAssertGreaterThan(flux, 0)
    }

    func testFftMagnitudes_dcEnergy() throws {
        let n = 1024
        let window = AudioFeatureExtractor.hannWindow(length: n)
        let dc = [Float](repeating: 1, count: n)
        let mags = try XCTUnwrap(AudioFeatureExtractor.fftMagnitudes(samples: dc, window: window))
        XCTAssertFalse(mags.isEmpty)
        XCTAssertGreaterThan(mags[0], 0)
    }
}
