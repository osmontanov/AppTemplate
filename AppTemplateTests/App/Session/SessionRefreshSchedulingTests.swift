import Foundation
import Testing
@testable import AppTemplate

struct SessionRefreshSchedulingTests {
    @Test @MainActor func automaticScheduleSleepsUntilExpiryMinusLeewayAndRefreshesOnce() async {
        let now = Date(timeIntervalSince1970: 1_000)
        let clock = RefreshScheduleClock(now: now)
        let oldExpiry = now.addingTimeInterval(300)
        let newExpiry = now.addingTimeInterval(900)
        let repository = ScheduledRefreshRepository(
            loginSnapshot: Self.snapshot(expiry: oldExpiry),
            refreshResult: .snapshot(Self.snapshot(expiry: newExpiry))
        )
        let controller = SessionController(
            repository: repository,
            clock: clock.clock,
            startupValidationPolicy: .disabled,
            refreshSchedulePolicy: .automatic
        )

        _ = await controller.login(username: "linus", password: "secret")
        await clock.waitUntilSleepStarts()
        #expect(await clock.requestedDuration == .seconds(240))

        await clock.release()
        await repository.waitUntilRefreshCount(1)
        for _ in 0..<10 { await Task.yield() }

        #expect(await repository.refreshCount == 1)
        #expect(controller.status.expiry?.accessExpiresAt == newExpiry)
    }

    @Test @MainActor func disabledPolicyAndMissingExpiryScheduleNothing() async {
        let clock = RefreshScheduleClock(now: Date(timeIntervalSince1970: 1_000))
        let repository = ScheduledRefreshRepository(
            loginSnapshot: Self.snapshot(expiry: nil),
            refreshResult: .unchanged
        )
        let controller = SessionController(
            repository: repository,
            clock: clock.clock,
            startupValidationPolicy: .disabled,
            refreshSchedulePolicy: .automatic
        )
        _ = await controller.login(username: "linus", password: "secret")
        for _ in 0..<10 { await Task.yield() }
        #expect(await clock.sleepCount == 0)
    }

    private static func snapshot(expiry: Date?) -> SessionRepositorySnapshot {
        .init(
            state: .authenticated(
                .init(id: 8, username: "linus", firstName: "Linus", lastName: "Torvalds", imageURL: nil),
                availability: .online
            ),
            expiry: .init(accessExpiresAt: expiry, refreshExpiresAt: nil)
        )
    }
}

private actor RefreshScheduleClock {
    private let date: Date
    private var continuation: CheckedContinuation<Void, Never>?
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private(set) var requestedDuration: Duration?
    private(set) var sleepCount = 0

    init(now: Date) { date = now }
    nonisolated var clock: AppClock {
        AppClock(
            now: { [date] in date },
            monotonicNow: { ContinuousClock().now },
            sleep: { [self] duration in await suspend(duration) }
        )
    }
    func waitUntilSleepStarts() async {
        guard sleepCount == 0 else { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func release() { continuation?.resume(); continuation = nil }
    private func suspend(_ duration: Duration) async {
        sleepCount += 1
        requestedDuration = duration
        let current = waiters
        waiters.removeAll()
        current.forEach { $0.resume() }
        await withCheckedContinuation { continuation = $0 }
    }
}

private actor ScheduledRefreshRepository: ISessionRepository {
    let loginSnapshot: SessionRepositorySnapshot
    let refreshResult: SessionRepositoryValidationResult
    private(set) var refreshCount = 0
    private var refreshWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
    init(loginSnapshot: SessionRepositorySnapshot, refreshResult: SessionRepositoryValidationResult) {
        self.loginSnapshot = loginSnapshot
        self.refreshResult = refreshResult
    }
    func beginBootstrapAttempt(_ attemptID: UInt64) {}
    func readBootstrapCandidate(attemptID: UInt64) -> SessionBootstrapReadResult { .staleAttempt }
    func resolveBootstrapCandidate(attemptID: UInt64) -> SessionRepositorySnapshot { loginSnapshot }
    func invalidateBootstrapAttempt(_ attemptID: UInt64) -> Bool { false }
    func login(username: String, password: String) -> SessionLoginResult { .authenticated(loginSnapshot) }
    func refreshStoredSession() -> SessionRepositoryValidationResult {
        refreshCount += 1
        let ready = refreshWaiters.filter { $0.0 <= refreshCount }
        refreshWaiters.removeAll { $0.0 <= refreshCount }
        ready.forEach { $0.1.resume() }
        return refreshResult
    }
    func waitUntilRefreshCount(_ count: Int) async {
        guard refreshCount < count else { return }
        await withCheckedContinuation { refreshWaiters.append((count, $0)) }
    }
}
