nonisolated enum SessionLoginFailure: Equatable, Sendable {
    case invalidCredentials
    case transport
    case serverUnavailable
    case rateLimited
    case responseInvalid
    case persistenceFailed(SessionPersistenceRetryToken)
    case concurrentAttempt
}

nonisolated enum SessionLoginResult: Equatable, Sendable {
    case authenticated(SessionRepositorySnapshot)
    case failure(SessionLoginFailure)
    case cancelled
}

nonisolated enum SessionPersistenceRetryResult: Equatable, Sendable {
    case committed(SessionRepositorySnapshot)
    case failed(SessionPersistenceRetryToken, retained: SessionRepositorySnapshot)
    case invalidToken
    case cancelled
}

nonisolated enum SessionPresentationError: Equatable, Sendable {
    case transport
    case serverUnavailable
    case rateLimited
    case responseInvalid
    case secureStorageReadFailed
    case secureStorageWriteFailed
    case secureStorageCleanupFailed
}

nonisolated enum SessionRepositoryValidationResult: Equatable, Sendable {
    case snapshot(SessionRepositorySnapshot)
    case persistenceFailed(SessionRepositorySnapshot, SessionPersistenceRetryToken)
    case unchanged
    case failed(SessionPresentationError)
    case cancelled
}

nonisolated enum SessionValidationResult: Equatable, Sendable {
    case committed(SessionPresentation)
    case persistenceFailed(SessionPersistenceRetryToken, retained: SessionPresentation)
    case unchanged
    case failed(SessionPresentationError)
    case cancelled
}

nonisolated enum SessionSignOutResult: Equatable, Sendable {
    case guest
    case deletionFailed
    case cancelled
}
