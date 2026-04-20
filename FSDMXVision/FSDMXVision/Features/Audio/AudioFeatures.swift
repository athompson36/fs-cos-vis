import Foundation

struct AudioFeatures {
    var rms: Float = 0
    var peak: Float = 0
    var lowBandEnergy: Float = 0
    var midBandEnergy: Float = 0
    var highBandEnergy: Float = 0
    var spectralFlux: Float = 0
    var estimatedBPM: Float = 0
    var beatConfidence: Float = 0
    /// Log-binned, attack/decay-smoothed FFT magnitudes (length 16) for composite spectrum warp.
    var spectrum16: [Float] = Array(repeating: 0, count: 16)
}
