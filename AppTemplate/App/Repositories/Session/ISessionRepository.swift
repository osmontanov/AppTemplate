nonisolated protocol ISessionRepository: Sendable {
    func beginBootstrapAttempt(_ attemptID: UInt64) async
    func readBootstrapCandidate(
        attemptID: UInt64
    ) async -> SessionBootstrapReadResult
    func resolveBootstrapCandidate(
        attemptID: UInt64
    ) async -> SessionRepositorySnapshot
    @discardableResult
    func invalidateBootstrapAttempt(_ attemptID: UInt64) async -> Bool
    func login(username: String, password: String) async -> SessionLoginResult
    func retryPersistence(
        _ token: SessionPersistenceRetryToken
    ) async -> SessionPersistenceRetryResult
    func discardPersistenceRetry(_ token: SessionPersistenceRetryToken) async
    func validateStoredSession() async -> SessionRepositoryValidationResult
    func refreshStoredSession() async -> SessionRepositoryValidationResult
    func signOut() async -> SessionSignOutResult
}

nonisolated extension ISessionRepository {
    func login(username: String, password: String) async -> SessionLoginResult {
        .failure(.responseInvalid)
    }

    func retryPersistence(
        _ token: SessionPersistenceRetryToken
    ) async -> SessionPersistenceRetryResult {
        .invalidToken
    }

    func discardPersistenceRetry(_ token: SessionPersistenceRetryToken) async {}
    func validateStoredSession() async -> SessionRepositoryValidationResult { .unchanged }
    func refreshStoredSession() async -> SessionRepositoryValidationResult { .unchanged }
    func signOut() async -> SessionSignOutResult { .cancelled }
}
