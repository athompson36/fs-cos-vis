import simd

/// Pure Swift blend helpers mirroring common GPU blend modes (unit-tested).
enum BlendMath {
    static func screen(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> SIMD3<Float> {
        1 - (1 - a) * (1 - b)
    }

    static func add(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> SIMD3<Float> {
        a + b
    }
}
