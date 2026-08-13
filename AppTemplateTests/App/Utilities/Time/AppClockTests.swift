import Foundation
import Testing
@testable import AppTemplate

struct AppClockTests {
    @Test
    func injectedClockControlsWallMonotonicAndSleepTime() async throws {
        let counter = SleepCounter()
        let instant = ContinuousClock().now
        let clock = AppClock(
            now: { Date(timeIntervalSince1970: 42) },
            monotonicNow: { instant },
            sleep: { duration in
                await counter.record(duration)
            }
        )

        try await clock.sleep(.seconds(9))

        #expect(clock.now() == Date(timeIntervalSince1970: 42))
        #expect(clock.monotonicNow() == instant)
        #expect(await counter.recordedDurations() == [.seconds(9)])
    }
}

private actor SleepCounter {
    private var durations: [Duration] = []

    func record(_ duration: Duration) {
        durations.append(duration)
    }

    func recordedDurations() -> [Duration] {
        durations
    }
}
