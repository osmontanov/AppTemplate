import Foundation
import Observation

@MainActor
@Observable
final class SessionController: ISessionActions {
    private(set) var status = SessionStatusPresentation(
        session: SessionPresentation(state: .restoring, revision: 0),
        expiry: nil
    )
    var presentation: SessionPresentation { status.session }
    private(set) var isLocalBootstrapResolved = false

    private let repository: any ISessionRepository
    private let clock: AppClock
    private let startupValidationPolicy: SessionStartupValidationPolicy
    private let refreshSchedulePolicy: SessionRefreshSchedulePolicy
    private var latestBootstrapAttemptID: UInt64 = 0
    private var operationGeneration: UInt64 = 0
    private var bootstrapOperationTask: Task<Void, Never>?
    private var bootstrapReadTask: Task<Void, Never>?
    private var bootstrapTimeoutTask: Task<Void, Never>?
    private var startupValidationTask: Task<Void, Never>?
    private var scheduledRefreshTask: Task<Void, Never>?
    private var scheduledExpiry: Date?
    private var attemptedExpiry: Date?

    init(
        repository: any ISessionRepository,
        clock: AppClock = .live,
        startupValidationPolicy: SessionStartupValidationPolicy,
        refreshSchedulePolicy: SessionRefreshSchedulePolicy
    ) {
        self.repository = repository
        self.clock = clock
        self.startupValidationPolicy = startupValidationPolicy
        self.refreshSchedulePolicy = refreshSchedulePolicy
    }

    isolated deinit {
        bootstrapOperationTask?.cancel()
        bootstrapReadTask?.cancel()
        bootstrapTimeoutTask?.cancel()
        startupValidationTask?.cancel()
        scheduledRefreshTask?.cancel()
    }

    func bootstrap() async {
        guard !isLocalBootstrapResolved else { return }
        await startOrJoinBootstrap()
    }

    func retryBootstrap() async {
        supersedeAutomation()
        await startOrJoinBootstrap()
    }

    func login(username: String, password: String) async -> SessionLoginResult {
        supersedeAutomation()
        let generation = operationGeneration
        let result = await repository.login(username: username, password: password)
        if case let .authenticated(snapshot) = result,
           generation == operationGeneration,
           !Task.isCancelled {
            commit(snapshot)
        }
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
        let generation = operationGeneration
        return mapValidation(
            await repository.validateStoredSession(),
            expectedGeneration: generation
        )
    }

    func refreshSession() async -> SessionValidationResult {
        let generation = operationGeneration
        return mapValidation(
            await repository.refreshStoredSession(),
            expectedGeneration: generation
        )
    }

    func signOut() async -> SessionSignOutResult {
        supersedeAutomation()
        let generation = operationGeneration
        let result = await repository.signOut()
        if result == .guest, generation == operationGeneration, !Task.isCancelled {
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
                startStartupValidationIfNeeded(for: snapshot)
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
        _ result: SessionRepositoryValidationResult,
        expectedGeneration: UInt64
    ) -> SessionValidationResult {
        guard expectedGeneration == operationGeneration, !Task.isCancelled else {
            return .cancelled
        }
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
        updateRefreshSchedule(for: snapshot)
    }

    private func startStartupValidationIfNeeded(
        for snapshot: SessionRepositorySnapshot
    ) {
        guard startupValidationPolicy == .automatic,
              case .authenticated(_, availability: .validating) = snapshot.state
        else { return }
        startupValidationTask?.cancel()
        let generation = operationGeneration
        let revision = status.session.revision
        let repository = repository
        startupValidationTask = Task { @MainActor [weak self, repository] in
            let result = await repository.validateStoredSession()
            guard let self else { return }
            guard !Task.isCancelled,
                  self.operationGeneration == generation,
                  self.status.session.revision == revision
            else { return }
            _ = self.mapValidation(result, expectedGeneration: generation)
            self.startupValidationTask = nil
        }
    }

    private func updateRefreshSchedule(for snapshot: SessionRepositorySnapshot) {
        guard refreshSchedulePolicy == .automatic,
              case .authenticated = snapshot.state,
              let expiry = snapshot.expiry?.accessExpiresAt,
              expiry != attemptedExpiry,
              expiry != scheduledExpiry
        else {
            if snapshot.expiry?.accessExpiresAt == nil {
                scheduledRefreshTask?.cancel()
                scheduledRefreshTask = nil
                scheduledExpiry = nil
            }
            return
        }
        scheduledRefreshTask?.cancel()
        scheduledExpiry = expiry
        let generation = operationGeneration
        let revision = status.session.revision
        let delay = max(0, expiry.addingTimeInterval(-60).timeIntervalSince(clock.now()))
        let clock = clock
        let repository = repository
        scheduledRefreshTask = Task { @MainActor [weak self, clock, repository] in
            do { try await clock.sleep(.seconds(delay)) } catch { return }
            guard !Task.isCancelled,
                  self?.operationGeneration == generation,
                  self?.status.session.revision == revision,
                  self?.scheduledExpiry == expiry
            else { return }
            self?.attemptedExpiry = expiry
            self?.scheduledExpiry = nil
            self?.scheduledRefreshTask = nil
            let result = await repository.refreshStoredSession()
            guard !Task.isCancelled,
                  self?.operationGeneration == generation
            else { return }
            _ = self?.mapValidation(result, expectedGeneration: generation)
        }
    }

    private func supersedeAutomation() {
        operationGeneration &+= 1
        startupValidationTask?.cancel()
        startupValidationTask = nil
        scheduledRefreshTask?.cancel()
        scheduledRefreshTask = nil
        scheduledExpiry = nil
        attemptedExpiry = nil
    }
}
