import XCTest
@testable import CosmicVisualizer

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
