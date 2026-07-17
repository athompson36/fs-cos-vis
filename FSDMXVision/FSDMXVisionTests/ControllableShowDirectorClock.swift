import Foundation
@testable import FSDMXVision

final class ControllableShowDirectorClock: ShowDirectorClock, @unchecked Sendable {
    private let lock = NSLock()
    private var current = Date(timeIntervalSince1970: 1_700_000_000)
    private var sleepHandler: (@Sendable (TimeInterval) async -> Void)?

    func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    func advance(seconds: TimeInterval) {
        lock.lock()
        current = current.addingTimeInterval(seconds)
        lock.unlock()
    }

    func setSleepHandler(_ handler: @escaping @Sendable (TimeInterval) async -> Void) {
        lock.lock()
        sleepHandler = handler
        lock.unlock()
    }

    private func snapshotSleepHandler() -> (@Sendable (TimeInterval) async -> Void)? {
        lock.lock()
        defer { lock.unlock() }
        return sleepHandler
    }

    func sleep(seconds: TimeInterval) async {
        if let handler = snapshotSleepHandler() {
            await handler(seconds)
        } else {
            try? await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
        }
    }
}
