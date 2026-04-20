import XCTest
@testable import FSDMXVision

final class ControlBusTests: XCTestCase {
    func testMIDIStub_lifecycle() {
        let bus = MIDIControlBusStub()
        XCTAssertFalse(bus.isRunning)
        bus.start()
        XCTAssertTrue(bus.isRunning)
        bus.stop()
        XCTAssertFalse(bus.isRunning)
    }

    func testOSCParse_floatMessage() throws {
        let r = try XCTUnwrap(OSCControlBusStub.parseSimpleMessage("/cosmic/bpm f 120.25"))
        XCTAssertEqual(r.address, "/cosmic/bpm")
        XCTAssertEqual(r.floatValue, 120.25, accuracy: 0.001)
    }

    func testOSCParse_commandMappingNextScene() throws {
        let cmd = try XCTUnwrap(OSCControlBusStub.parseCommand("/cosmic/scene/next"))
        XCTAssertEqual(cmd.type, "NextScene")
    }

    func testOSCParse_commandMappingFractalZoom() throws {
        let cmd = try XCTUnwrap(OSCControlBusStub.parseCommand("/cosmic/fractal/zoom f 1.75"))
        XCTAssertEqual(cmd.type, "SetFractalZoom")
        XCTAssertEqual(try XCTUnwrap(cmd.fractalZoom), 1.75, accuracy: 0.001)
    }

    func testOSCParse_commandMappingTempoBPM() throws {
        let cmd = try XCTUnwrap(OSCControlBusStub.parseCommand("/cosmic/tempo/bpm f 128.0"))
        XCTAssertEqual(cmd.type, "SetManualBPM")
        XCTAssertEqual(try XCTUnwrap(cmd.bpm), 128.0, accuracy: 0.001)
    }

    func testOSCParse_commandMappingLiquidEnabled() throws {
        let cmd = try XCTUnwrap(OSCControlBusStub.parseCommand("/cosmic/liquid/enabled f 1"))
        XCTAssertEqual(cmd.type, "SetLiquidLightEnabled")
        XCTAssertEqual(cmd.enabled, true)
    }

    func testOSCParse_commandMappingSceneJumpUUID() throws {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
        let cmd = try XCTUnwrap(OSCControlBusStub.parseCommand("/cosmic/scene/jump \(id.uuidString)"))
        XCTAssertEqual(cmd.type, "JumpToScene")
        XCTAssertEqual(cmd.sceneID, id)
    }

    func testOSCParse_commandMappingPaletteSelectUUID() throws {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000222")!
        let cmd = try XCTUnwrap(OSCControlBusStub.parseCommand("/cosmic/palette/select s \(id.uuidString)"))
        XCTAssertEqual(cmd.type, "SetSelectedPalette")
        XCTAssertEqual(cmd.paletteID, id)
    }

    func testOSCParse_commandMappingLightingCueIndex() throws {
        let cmd = try XCTUnwrap(OSCControlBusStub.parseCommand("/cosmic/lighting/cue/index i 3"))
        XCTAssertEqual(cmd.type, "SetActiveLightingCueIndex")
        XCTAssertEqual(cmd.index, 3)

        let nextCue = try XCTUnwrap(OSCControlBusStub.parseCommand("/cosmic/lighting/cue/next"))
        XCTAssertEqual(nextCue.type, "NextLightingCue")

        let prevCue = try XCTUnwrap(OSCControlBusStub.parseCommand("/cosmic/lighting/cue/previous"))
        XCTAssertEqual(prevCue.type, "PreviousLightingCue")

        let sceneIdx = try XCTUnwrap(OSCControlBusStub.parseCommand("/cosmic/scene/index i 2"))
        XCTAssertEqual(sceneIdx.type, "JumpToSceneIndex")
        XCTAssertEqual(sceneIdx.index, 2)

        let tempoSrc = try XCTUnwrap(OSCControlBusStub.parseCommand("/cosmic/tempo/source s manual"))
        XCTAssertEqual(tempoSrc.type, "SetTempoSource")
        XCTAssertEqual(tempoSrc.source, "manual")

        let liquidFocus = try XCTUnwrap(OSCControlBusStub.parseCommand("/cosmic/liquid/focus f 0.5"))
        XCTAssertEqual(liquidFocus.type, "SetLiquidFocus")
        XCTAssertEqual(liquidFocus.liquidFocus, 0.5)

        let zoomEffect = try XCTUnwrap(OSCControlBusStub.parseCommand("/cosmic/fractal/zoom_effect i 1"))
        XCTAssertEqual(zoomEffect.type, "SetZoomEffectType")
        XCTAssertEqual(zoomEffect.index, 1)

        let spectrumWarp = try XCTUnwrap(OSCControlBusStub.parseCommand("/cosmic/composite/spectrum_warp f 0.4"))
        XCTAssertEqual(spectrumWarp.type, "SetSpectrumWarpAmount")
        let sw = try XCTUnwrap(spectrumWarp.spectrumWarpAmount)
        XCTAssertEqual(sw, 0.4, accuracy: 0.001)

        let fracGeo = try XCTUnwrap(OSCControlBusStub.parseCommand("/cosmic/fractal/geometry i 5"))
        XCTAssertEqual(fracGeo.type, "SetFractalGeometryIndex")
        XCTAssertEqual(fracGeo.index, 5)
    }

    func testOSCParse_commandMappingRecordingStart() throws {
        let cmd = try XCTUnwrap(OSCControlBusStub.parseCommand("/cosmic/recording/start"))
        XCTAssertEqual(cmd.type, "StartLiveOutputRecording")
    }

    func testOSCParse_commandMappingRecordingSource() throws {
        let cmd = try XCTUnwrap(OSCControlBusStub.parseCommand("/cosmic/recording/source s externalOutput"))
        XCTAssertEqual(cmd.type, "SetLiveOutputRecordingSource")
        XCTAssertEqual(cmd.source, "externalOutput")
    }

    func testOSCParse_stateQuery() {
        XCTAssertTrue(OSCControlBusStub.isStateQuery("/cosmic/state/get"))
        XCTAssertFalse(OSCControlBusStub.isStateQuery("/cosmic/scene/next"))
    }

    func testDMXClamp() {
        XCTAssertEqual(DMXControlStub.clampChannel(300), 255)
        XCTAssertEqual(DMXControlStub.clampChannel(-10), 0)
    }

    func testCaptureSession_idleEndDoesNotStartRecording() async {
        let c = CaptureSession()
        XCTAssertFalse(c.isRecording)
        await c.end()
        XCTAssertFalse(c.isRecording)
    }
}
