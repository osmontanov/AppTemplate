import Foundation
import Testing
@testable import AppTemplate

struct SessionControllerBootstrapTests {
    private let sessionKey = KeychainKey.data("Store.AuthSession")

    @Test @MainActor func timeoutRejectsLateReadAndRetryReadsFresh() async throws {
        let readGate = BootstrapReadGate()
        let deadline = ManualBootstrapDeadline()
        let envelope = fixtureEnvelope()
        let keychain = KeychainServiceSpy(
            storage: [sessionKey: try JSONEncoder().encode(envelope)],
            beforeReadAsync: { await readGate.suspendFirstRead() }
        )
        let repository = SessionRepository(
            remote: BootstrapUnusedRemoteService(),
            secureStore: SessionSecureStore(keychain: keychain)
        )
        let controller = SessionController(
            repository: repository,
            clock: deadline.clock,
            startupValidationPolicy: .disabled,
            refreshSchedulePolicy: .disabled
        )

        async let first: Void = controller.bootstrap()
        await readGate.waitUntilFirstReadStarts()
        await deadline.waitUntilSleepStarts(ordinal: 1)
        #expect(await deadline.requestedDuration(ordinal: 1) == .seconds(3))
        await deadline.release(ordinal: 1)
        await first

        #expect(controller.isLocalBootstrapResolved)
        #expect(controller.status == unavailableStatus(revision: 1))
        let countsAtTimeout = await keychain.callCounts()
        #expect(countsAtTimeout.reads == 1)
        #expect(countsAtTimeout.writes == 0)
        #expect(countsAtTimeout.removals == 0)

        await keychain.replaceStoredData(nil, for: sessionKey)
        await readGate.releaseFirstRead()
        for _ in 0..<10 { await Task.yield() }
        #expect(controller.status == unavailableStatus(revision: 1))
        #expect(await keychain.callCounts().writes == 0)
        #expect(await keychain.callCounts().removals == 0)

        await controller.retryBootstrap()

        #expect(controller.status == SessionStatusPresentation(
            session: SessionPresentation(state: .guest, revision: 2),
            expiry: nil
        ))
        #expect(await keychain.callCounts().reads == 2)
    }

    @Test @MainActor func cancellationIgnoringLateReadDoesNotRetainController() async throws {
        let readGate = BootstrapReadGate()
        let deadline = ManualBootstrapDeadline()
        let keychain = KeychainServiceSpy(
            storage: [sessionKey: try JSONEncoder().encode(fixtureEnvelope())],
            beforeReadAsync: { await readGate.suspendFirstRead() }
        )
        let repository = SessionRepository(
            remote: BootstrapUnusedRemoteService(),
            secureStore: SessionSecureStore(keychain: keychain)
        )
        var controller: SessionController? = SessionController(
            repository: repository,
            clock: deadline.clock,
            startupValidationPolicy: .disabled,
            refreshSchedulePolicy: .disabled
        )
        weak let weakController = controller

        let bootstrapTask = Task { @MainActor [weak controller] in
            await controller?.bootstrap()
        }
        await readGate.waitUntilFirstReadStarts()
        await deadline.waitUntilSleepStarts(ordinal: 1)
        await deadline.release(ordinal: 1)
        await bootstrapTask.value

        controller = nil
        #expect(weakController == nil)
        await readGate.releaseFirstRead()
    }

    @Test @MainActor func concurrentBootstrapCallsJoinOneAttemptAndOneRead() async {
        let repository = ControlledBootstrapRepository(
            snapshot: SessionRepositorySnapshot(state: .guest, expiry: nil)
        )
        let deadline = ManualBootstrapDeadline()
        let controller = SessionController(
            repository: repository,
            clock: deadline.clock,
            startupValidationPolicy: .disabled,
            refreshSchedulePolicy: .disabled
        )

        async let first: Void = controller.bootstrap()
        async let second: Void = controller.bootstrap()
        await repository.waitUntilReadStarts()
        #expect(await repository.recordedAttemptIDs() == [1])
        #expect(await repository.readCount == 1)
        await repository.releaseRead()
        _ = await (first, second)

        #expect(controller.status == SessionStatusPresentation(
            session: SessionPresentation(state: .guest, revision: 1),
            expiry: nil
        ))
        #expect(await repository.readCount == 1)
    }

    @Test @MainActor func validBootstrapPublishesStateAndExactExpiryAsOneStatus() async throws {
        let envelope = fixtureEnvelope()
        let keychain = KeychainServiceSpy(storage: [
            sessionKey: try JSONEncoder().encode(envelope)
        ])
        let repository = SessionRepository(
            remote: BootstrapUnusedRemoteService(),
            secureStore: SessionSecureStore(keychain: keychain)
        )
        let deadline = ManualBootstrapDeadline()
        let controller = SessionController(
            repository: repository,
            clock: deadline.clock,
            startupValidationPolicy: .disabled,
            refreshSchedulePolicy: .disabled
        )

        await controller.bootstrap()

        #expect(controller.status == SessionStatusPresentation(
            session: SessionPresentation(
                state: .authenticated(envelope.profile, availability: .validating),
                revision: 1
            ),
            expiry: SessionExpiryPresentation(
                accessExpiresAt: envelope.accessExpiresAt,
                refreshExpiresAt: envelope.refreshExpiresAt
            )
        ))
        #expect(controller.presentation == controller.status.session)
    }

    @Test @MainActor func resolvedBootstrapIsIdempotentButRetryUsesLargerID() async {
        let repository = ImmediateBootstrapRepository()
        let controller = SessionController(
            repository: repository,
            startupValidationPolicy: .disabled,
            refreshSchedulePolicy: .disabled
        )

        await controller.bootstrap()
        await controller.bootstrap()
        #expect(await repository.recordedAttemptIDs() == [1])

        await controller.retryBootstrap()

        #expect(await repository.recordedAttemptIDs() == [1, 2])
    }

    private func unavailableStatus(revision: UInt64) -> SessionStatusPresentation {
        SessionStatusPresentation(
            session: SessionPresentation(
                state: .unavailable(.secureStorageReadFailed),
                revision: revision
            ),
            expiry: nil
        )
    }

    private func fixtureEnvelope() -> StoredSessionEnvelope {
        StoredSessionEnvelope(
            schemaVersion: 1,
            profile: UserProfile(
                id: 101,
                username: "late-reader",
                firstName: "Katherine",
                lastName: "Johnson",
                imageURL: URL(string: "https://example.test/katherine.png")
            ),
            accessToken: "late-access",
            refreshToken: "late-refresh",
            accessExpiresAt: Date(timeIntervalSince1970: 1_900_000_000),
            refreshExpiresAt: Date(timeIntervalSince1970: 1_900_086_400)
        )
    }
}

private actor ManualBootstrapDeadline {
    private struct SleepCall {
        let duration: Duration
        let continuation: CheckedContinuation<Void, Never>
    }

    private var calls: [SleepCall] = []
    private var callWaiters: [(Int, CheckedContinuation<Void, Never>)] = []

    nonisolated var clock: AppClock {
        AppClock(
            now: Date.init,
            monotonicNow: { ContinuousClock().now },
            sleep: { [self] duration in await suspend(for: duration) }
        )
    }

    func waitUntilSleepStarts(ordinal: Int) async {
        guard calls.count < ordinal else { return }
        await withCheckedContinuation { callWaiters.append((ordinal, $0)) }
    }

    func requestedDuration(ordinal: Int) -> Duration? {
        guard calls.indices.contains(ordinal - 1) else { return nil }
        return calls[ordinal - 1].duration
    }

    func release(ordinal: Int) {
        guard calls.indices.contains(ordinal - 1) else { return }
        calls[ordinal - 1].continuation.resume()
    }

    private func suspend(for duration: Duration) async {
        await withCheckedContinuation { continuation in
            calls.append(SleepCall(duration: duration, continuation: continuation))
            let count = calls.count
            let ready = callWaiters.filter { $0.0 <= count }
            callWaiters.removeAll { $0.0 <= count }
            for waiter in ready { waiter.1.resume() }
        }
    }
}

private actor ControlledBootstrapRepository: ISessionRepository {
    private let snapshot: SessionRepositorySnapshot
    private var attempts: [UInt64] = []
    private(set) var readCount = 0
    private var readContinuation: CheckedContinuation<Void, Never>?
    private var readStartWaiters: [CheckedContinuation<Void, Never>] = []

    init(snapshot: SessionRepositorySnapshot) {
        self.snapshot = snapshot
    }

    func beginBootstrapAttempt(_ attemptID: UInt64) {
        attempts.append(attemptID)
    }

    func readBootstrapCandidate(attemptID: UInt64) async -> SessionBootstrapReadResult {
        readCount += 1
        let waiters = readStartWaiters
        readStartWaiters.removeAll()
        for waiter in waiters { waiter.resume() }
        await withCheckedContinuation { readContinuation = $0 }
        return .candidateReady
    }

    func resolveBootstrapCandidate(attemptID: UInt64) -> SessionRepositorySnapshot {
        snapshot
    }

    func invalidateBootstrapAttempt(_ attemptID: UInt64) -> Bool { false }

    func waitUntilReadStarts() async {
        guard readCount == 0 else { return }
        await withCheckedContinuation { readStartWaiters.append($0) }
    }

    func releaseRead() {
        readContinuation?.resume()
        readContinuation = nil
    }

    func recordedAttemptIDs() -> [UInt64] { attempts }
}

private actor ImmediateBootstrapRepository: ISessionRepository {
    private var attempts: [UInt64] = []

    func beginBootstrapAttempt(_ attemptID: UInt64) {
        attempts.append(attemptID)
    }

    func readBootstrapCandidate(
        attemptID: UInt64
    ) -> SessionBootstrapReadResult {
        .candidateReady
    }

    func resolveBootstrapCandidate(
        attemptID: UInt64
    ) -> SessionRepositorySnapshot {
        SessionRepositorySnapshot(state: .guest, expiry: nil)
    }

    func invalidateBootstrapAttempt(_ attemptID: UInt64) -> Bool { false }

    func recordedAttemptIDs() -> [UInt64] { attempts }
}
