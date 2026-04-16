import XCTest
import simd
@testable import CosmicVisualizer

final class RenderParametersTests: XCTestCase {
    func testUniforms_liquidDisabled_zeroLiquidMix() {
        var p = RenderParameters()
        p.liquidLightEnabled = false
        p.liquidMix = 1
        let u = p.uniforms(drawableSize: CGSize(width: 800, height: 600))
        XCTAssertEqual(u.liquidMix, 0)
        XCTAssertEqual(u.resolution.x, 800)
        XCTAssertEqual(u.resolution.y, 600)
    }

    func testUniforms_fractalMix_passedThrough() {
        var p = RenderParameters()
        p.fractalMix = 0.75
        let u = p.uniforms(drawableSize: CGSize(width: 100, height: 100))
        XCTAssertEqual(u.fractalMix, 0.75)
    }

    func testUniforms_fractalKind_passedThrough() {
        var p = RenderParameters()
        p.fractalKind = 1
        let u = p.uniforms(drawableSize: CGSize(width: 64, height: 64))
        XCTAssertEqual(u.fractalKind, 1)
    }

    func testUniforms_extendedKnobs_passedThrough() {
        var p = RenderParameters()
        p.beatPulse = 0.8
        p.fractalZoom = 1.4
        p.liquidTurbulence = 1.1
        p.compositeBlend = 0.42
        let u = p.uniforms(drawableSize: CGSize(width: 10, height: 10))
        XCTAssertEqual(u.beatPulse, 0.8)
        XCTAssertEqual(u.fractalZoom, 1.4)
        XCTAssertEqual(u.liquidTurbulence, 1.1)
        XCTAssertEqual(u.compositeBlend, 0.42)
        XCTAssertGreaterThan(MemoryLayout<CosmicUniforms>.stride, 40)
    }

    func testUniforms_paletteAndFocus_passedThrough() {
        var p = RenderParameters()
        p.paletteAccent = SIMD4<Float>(0.1, 0.2, 0.3, 0)
        p.liquidFocus = 0.25
        p.fractalAppearance = 1
        p.overlayFractalFusion = 0.7
        p.overlayOpacity = 0.5
        let u = p.uniforms(drawableSize: CGSize(width: 4, height: 4))
        XCTAssertEqual(u.paletteAccent.x, 0.1, accuracy: 0.001)
        XCTAssertEqual(u.liquidFocus, 0.25, accuracy: 0.001)
        XCTAssertEqual(u.fractalAppearance, 1, accuracy: 0.001)
        XCTAssertEqual(u.overlayFractalFusion, 0.7, accuracy: 0.001)
        XCTAssertEqual(u.overlayOpacity, 0.5, accuracy: 0.001)
    }
}
