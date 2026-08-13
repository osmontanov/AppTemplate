import Foundation

actor SessionRepository: ISessionRepository {
    private let remote: any IRemoteService
    private let secureStore: SessionSecureStore
    private let clock: AppClock
    private let refreshLeeway: TimeInterval

    private var activeBootstrapAttemptID: UInt64?
    private var bootstrapCandidate: SessionSecureStoreReadResult?
    private var bootstrapCandidateAttemptID: UInt64?

    init(
        remote: any IRemoteService,
        secureStore: SessionSecureStore,
        clock: AppClock = .live,
        refreshLeeway: TimeInterval = 60
    ) {
        self.remote = remote
        self.secureStore = secureStore
        self.clock = clock
        self.refreshLeeway = refreshLeeway
    }

    func beginBootstrapAttempt(_ attemptID: UInt64) {
        activeBootstrapAttemptID = attemptID
        bootstrapCandidate = nil
        bootstrapCandidateAttemptID = nil
    }

    func readBootstrapCandidate(
        attemptID: UInt64
    ) async -> SessionBootstrapReadResult {
        do {
            let result = try await secureStore.read()
            guard activeBootstrapAttemptID == attemptID else {
                return .staleAttempt
            }
            bootstrapCandidate = result
            bootstrapCandidateAttemptID = attemptID
            activeBootstrapAttemptID = nil
            return .candidateReady
        } catch {
            guard activeBootstrapAttemptID == attemptID else {
                return .staleAttempt
            }
            bootstrapCandidate = nil
            bootstrapCandidateAttemptID = attemptID
            activeBootstrapAttemptID = nil
            return .readFailed
        }
    }

    func resolveBootstrapCandidate(
        attemptID: UInt64
    ) async -> SessionRepositorySnapshot {
        guard bootstrapCandidateAttemptID == attemptID else {
            return readFailureSnapshot
        }

        switch bootstrapCandidate {
        case .missing:
            clearBootstrapCandidate(attemptID: attemptID)
            return SessionRepositorySnapshot(state: .guest, expiry: nil)

        case let .envelope(envelope):
            clearBootstrapCandidate(attemptID: attemptID)
            return SessionRepositorySnapshot(
                state: .authenticated(
                    envelope.profile,
                    availability: .validating
                ),
                expiry: SessionExpiryPresentation(
                    accessExpiresAt: envelope.accessExpiresAt,
                    refreshExpiresAt: envelope.refreshExpiresAt
                )
            )

        case .corruptEnvelope:
            guard bootstrapCandidateAttemptID == attemptID else {
                return readFailureSnapshot
            }
            do {
                _ = try await secureStore.remove()
                guard bootstrapCandidateAttemptID == attemptID else {
                    return readFailureSnapshot
                }
                clearBootstrapCandidate(attemptID: attemptID)
                return SessionRepositorySnapshot(state: .guest, expiry: nil)
            } catch {
                guard bootstrapCandidateAttemptID == attemptID else {
                    return readFailureSnapshot
                }
                clearBootstrapCandidate(attemptID: attemptID)
                return SessionRepositorySnapshot(
                    state: .unavailable(.secureStorageCleanupFailed),
                    expiry: nil
                )
            }

        case .unsupportedSchema, .none:
            clearBootstrapCandidate(attemptID: attemptID)
            return readFailureSnapshot
        }
    }

    func invalidateBootstrapAttempt(_ attemptID: UInt64) -> Bool {
        guard activeBootstrapAttemptID == attemptID else { return false }
        activeBootstrapAttemptID = nil
        if bootstrapCandidateAttemptID == attemptID {
            bootstrapCandidate = nil
            bootstrapCandidateAttemptID = nil
        }
        return true
    }

    private var readFailureSnapshot: SessionRepositorySnapshot {
        SessionRepositorySnapshot(
            state: .unavailable(.secureStorageReadFailed),
            expiry: nil
        )
    }

    private func clearBootstrapCandidate(attemptID: UInt64) {
        guard bootstrapCandidateAttemptID == attemptID else { return }
        bootstrapCandidate = nil
        bootstrapCandidateAttemptID = nil
    }
}
