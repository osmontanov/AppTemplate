import Foundation

nonisolated
struct AppClock: Sendable {
    let now: @Sendable () -> Date
    let monotonicNow: @Sendable () -> ContinuousClock.Instant
    let sleep: @Sendable (Duration) async throws -> Void

    static let live = AppClock(
        now: Date.init,
        monotonicNow: { ContinuousClock().now },
        sleep: { try await Task.sleep(for: $0) }
    )
}
