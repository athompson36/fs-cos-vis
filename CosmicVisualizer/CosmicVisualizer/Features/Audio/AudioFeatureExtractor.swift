import Accelerate
import AVFoundation
import Foundation

/// Pure analysis helpers used by `AudioEngine` and unit tests.
enum AudioFeatureExtractor {
    /// Mixes non-interleaved PCM to mono `Float` samples in [-1, 1].
    static func monoFloatSamples(from buffer: AVAudioPCMBuffer) -> [Float]? {
        guard let floatChannelData = buffer.floatChannelData else { return nil }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return [] }

        let channelCount = Int(buffer.format.channelCount)
        guard channelCount > 0 else { return [] }

        if channelCount == 1 {
            return Array(UnsafeBufferPointer(start: floatChannelData[0], count: frameCount))
        }

        var mono = [Float](repeating: 0, count: frameCount)
        var scale = 1.0 / Float(channelCount)
        for channel in 0..<channelCount {
            let channelPtr = floatChannelData[channel]
            vDSP_vsma(channelPtr, 1, &scale, mono, 1, &mono, 1, vDSP_Length(frameCount))
        }
        return mono
    }

    static func rmsAndPeak(samples: [Float]) -> (rms: Float, peak: Float) {
        guard !samples.isEmpty else { return (0, 0) }
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        var peak: Float = 0
        vDSP_maxmgv(samples, 1, &peak, vDSP_Length(samples.count))
        return (rms, peak)
    }

    /// Hann window of length N.
    static func hannWindow(length: Int) -> [Float] {
        guard length > 0 else { return [] }
        var window = [Float](repeating: 0, count: length)
        vDSP_hann_window(&window, vDSP_Length(length), Int32(vDSP_HANN_NORM))
        return window
    }

    /// Real input FFT magnitude squared per bin (length `count / 2` for unique positive spectrum).
    static func fftMagnitudes(samples: [Float], window: [Float]) -> [Float]? {
        let n = samples.count
        guard n.isPowerOfTwo, window.count == n else { return nil }

        var windowed = samples
        vDSP_vmul(windowed, 1, window, 1, &windowed, 1, vDSP_Length(n))

        let dft: vDSP.DiscreteFourierTransform<Float>
        do {
            dft = try vDSP.DiscreteFourierTransform(count: n, direction: .forward, transformType: .complexReal, ofType: Float.self)
        } catch {
            return nil
        }

        let zeros = [Float](repeating: 0, count: n)
        var outputReal = [Float](repeating: 0, count: n / 2 + 1)
        var outputImag = [Float](repeating: 0, count: n / 2 + 1)
        dft.transform(
            inputReal: windowed,
            inputImaginary: zeros,
            outputReal: &outputReal,
            outputImaginary: &outputImag
        )
        let binCount = min(outputReal.count, outputImag.count)
        var mags = [Float](repeating: 0, count: binCount)
        for k in 0..<binCount {
            let r = outputReal[k]
            let i = outputImag[k]
            mags[k] = r * r + i * i
        }
        return mags
    }

    /// Spectral flux: half-wave rectified difference between consecutive magnitude spectra.
    static func spectralFlux(previous: [Float], current: [Float]) -> Float {
        guard previous.count == current.count, !current.isEmpty else { return 0 }
        var sum: Float = 0
        for i in current.indices {
            let d = current[i] - previous[i]
            if d > 0 { sum += d }
        }
        return sum
    }

    static func bandEnergies(magnitudes: [Float]) -> (low: Float, mid: Float, high: Float) {
        guard magnitudes.count >= 3 else { return (0, 0, 0) }
        let n = magnitudes.count
        let lowEnd = n / 3
        let midEnd = (2 * n) / 3
        let low = magnitudes[0..<lowEnd].reduce(0, +)
        let mid = magnitudes[lowEnd..<midEnd].reduce(0, +)
        let high = magnitudes[midEnd..<n].reduce(0, +)
        return (low, mid, high)
    }
}

private extension Int {
    var isPowerOfTwo: Bool {
        self > 0 && (self & (self - 1)) == 0
    }
}
