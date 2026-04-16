import XCTest
@testable import CosmicVisualizer

final class TempoClockServiceTests: XCTestCase {
    func testTapTempo_updatesEffectiveBPM() {
        let clock = TempoClockService()
        clock.setSyncSource(.tapTempo)
        clock.tap()
        usleep(350_000)
        clock.tap()
        XCTAssertGreaterThan(clock.effectiveBPM, 0)
    }

    func testManualSource_usesManualBPM() {
        let clock = TempoClockService()
        clock.manualBPM = 99
        clock.setSyncSource(.manual)
        XCTAssertEqual(clock.effectiveBPM, 99, accuracy: 0.01)
    }

    func testMIDIClockTick_advancesPhase() {
        let clock = TempoClockService()
        clock.setSyncSource(.midiClock)
        clock.ingestMIDIClockTick()
        XCTAssertGreaterThanOrEqual(clock.beatPhase, 0)
    }
}
