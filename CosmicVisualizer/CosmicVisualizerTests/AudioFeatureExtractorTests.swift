import XCTest
import AVFoundation
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

    func testStereoPairMonoSamples_averagesPair() throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4)!
        buffer.frameLength = 4
        let l = buffer.floatChannelData![0]
        let r = buffer.floatChannelData![1]
        l[0] = 1; l[1] = 0; l[2] = -1; l[3] = 0.5
        r[0] = 0; r[1] = 1; r[2] = 1; r[3] = 0.5
        let mono = try XCTUnwrap(AudioFeatureExtractor.stereoPairMonoSamples(from: buffer, pairStartIndex: 0))
        XCTAssertEqual(mono[0], 0.5, accuracy: 0.0001)
        XCTAssertEqual(mono[1], 0.5, accuracy: 0.0001)
        XCTAssertEqual(mono[2], 0.0, accuracy: 0.0001)
        XCTAssertEqual(mono[3], 0.5, accuracy: 0.0001)
    }
}
