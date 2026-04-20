import XCTest
@testable import FSDMXVision

final class AudioDeviceEnumeratorTests: XCTestCase {
    func testInputDevices_returnsArray() throws {
        let devices = AudioDeviceEnumerator.inputDevices()
        if devices.isEmpty {
            throw XCTSkip("No input devices in this environment")
        }
        XCTAssertFalse(devices[0].name.isEmpty)
        XCTAssertNotNil(AudioDeviceEnumerator.defaultInputDeviceID())
    }
}
