import Foundation
import Observation

@MainActor
@Observable
final class SessionController {
    private(set) var status = SessionStatusPresentation(
        session: SessionPresentation(state: .restoring, revision: 0),
        expiry: nil
    )
    var presentation: SessionPresentation { status.session }
    private(set) var isLocalBootstrapResolved = false

    private let repository: any ISessionRepository
    private let clock: AppClock
    private var latestBootstrapAttemptID: UInt64 = 0
    private var bootstrapOperationTask: Task<Void, Never>?
    private var bootstrapReadTask: Task<Void, Never>?
    private var bootstrapTimeoutTask: Task<Void, Never>?

    init(
        repository: any ISessionRepository,
        clock: AppClock = .live
    ) {
        self.repository = repository
        self.clock = clock
    }

    func bootstrap() async {
        guard !isLocalBootstrapResolved else { return }
        await startOrJoinBootstrap()
    }

    func retryBootstrap() async {
        await startOrJoinBootstrap()
    }

    func login(username: String, password: String) async -> SessionLoginResult {
        let result = await repository.login(username: username, password: password)
        if case let .authenticated(snapshot) = result { commit(snapshot) }
        return result
    }

    func retryPersistence(
        _ token: SessionPersistenceRetryToken
    ) async -> SessionPersistenceRetryResult {
        let result = await repository.retryPersistence(token)
        switch result {
        case let .committed(snapshot), let .failed(_, retained: snapshot):
            commit(snapshot)
        case .invalidToken, .cancelled:
            break
        }
        return result
    }

    func discardPersistenceRetry(_ token: SessionPersistenceRetryToken) async {
        await repository.discardPersistenceRetry(token)
    }

    func validateSession() async -> SessionValidationResult {
        mapValidation(await repository.validateStoredSession())
    }

    func refreshSession() async -> SessionValidationResult {
        mapValidation(await repository.refreshStoredSession())
    }

    func signOut() async -> SessionSignOutResult {
        let result = await repository.signOut()
        if result == .guest {
            commit(SessionRepositorySnapshot(state: .guest, expiry: nil))
        }
        return result
    }

    private func startOrJoinBootstrap() async {
        if let bootstrapOperationTask {
            await bootstrapOperationTask.value
            return
        }

        let operation = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.runBootstrapRace()
        }
        bootstrapOperationTask = operation
        await operation.value
    }

    private func runBootstrapRace() async {
        defer { bootstrapOperationTask = nil }
        guard let attemptID = nextBootstrapAttemptID() else {
            commitReadFailure()
            return
        }

        await repository.beginBootstrapAttempt(attemptID)
        let signal = AsyncOneShotSignal<SessionBootstrapRaceWinner>()
        let repository = repository
        let clock = clock

        let readTask = Task { [repository, signal, attemptID] in
            let result = await repository.readBootstrapCandidate(
                attemptID: attemptID
            )
            guard !Task.isCancelled, result != .staleAttempt else { return }
            _ = await signal.resolve(.read(result))
        }
        let timeoutTask = Task { [repository, signal, clock, attemptID] in
            do {
                try await clock.sleep(.seconds(3))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            let invalidated = await repository.invalidateBootstrapAttempt(
                attemptID
            )
            guard invalidated, !Task.isCancelled else { return }
            _ = await signal.resolve(.timeout)
        }
        bootstrapReadTask = readTask
        bootstrapTimeoutTask = timeoutTask

        let winner = await signal.wait()
        bootstrapReadTask = nil
        bootstrapTimeoutTask = nil

        switch winner {
        case .timeout:
            readTask.cancel()
            commitReadFailure()

        case let .read(result):
            timeoutTask.cancel()
            guard !Task.isCancelled else { return }
            switch result {
            case .candidateReady, .readFailed:
                let snapshot = await repository.resolveBootstrapCandidate(
                    attemptID: attemptID
                )
                guard !Task.isCancelled else { return }
                commit(snapshot)
            case .staleAttempt:
                return
            }
        }
    }

    private func nextBootstrapAttemptID() -> UInt64? {
        guard latestBootstrapAttemptID < .max else { return nil }
        latestBootstrapAttemptID += 1
        return latestBootstrapAttemptID
    }

    private func commitReadFailure() {
        commit(SessionRepositorySnapshot(
            state: .unavailable(.secureStorageReadFailed),
            expiry: nil
        ))
    }

    private func mapValidation(
        _ result: SessionRepositoryValidationResult
    ) -> SessionValidationResult {
        switch result {
        case let .snapshot(snapshot):
            commit(snapshot)
            return .committed(presentation)
        case let .persistenceFailed(snapshot, token):
            commit(snapshot)
            return .persistenceFailed(token, retained: presentation)
        case .unchanged:
            return .unchanged
        case let .failed(error):
            return .failed(error)
        case .cancelled:
            return .cancelled
        }
    }

    private func commit(_ snapshot: SessionRepositorySnapshot) {
        guard status.session.state != snapshot.state || status.expiry != snapshot.expiry else {
            isLocalBootstrapResolved = true
            return
        }
        let revision = status.session.revision &+ 1
        status = SessionStatusPresentation(
            session: SessionPresentation(
                state: snapshot.state,
                revision: revision
            ),
            expiry: snapshot.expiry
        )
        isLocalBootstrapResolved = true
    }
}
