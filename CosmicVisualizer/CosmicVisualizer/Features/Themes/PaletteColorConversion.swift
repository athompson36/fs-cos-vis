import Foundation
import simd

enum PaletteColorConversion {
    /// Parses `#RRGGBB` into linear-ish sRGB 0…1 components.
    static func simd4(fromHexRGB hex: String) -> SIMD4<Float> {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else {
            return SIMD4<Float>(0.5, 0.5, 0.5, 0)
        }
        let r = Float((v >> 16) & 0xFF) / 255
        let g = Float((v >> 8) & 0xFF) / 255
        let b = Float(v & 0xFF) / 255
        return SIMD4<Float>(r, g, b, 0)
    }

    static func simdColors(from palette: ThemePalette) -> (
        SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>
    ) {
        (
            simd4(fromHexRGB: palette.primaryHex),
            simd4(fromHexRGB: palette.secondaryHex),
            simd4(fromHexRGB: palette.accentHex),
            simd4(fromHexRGB: palette.glowHex)
        )
    }
}
