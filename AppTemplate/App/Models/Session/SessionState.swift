nonisolated enum SessionState: Equatable, Sendable {
    case restoring
    case guest
    case unavailable(SessionUnavailableReason)
    case authenticated(UserProfile, availability: SessionAvailability)
}

nonisolated enum SessionUnavailableReason: Hashable, Sendable {
    case secureStorageReadFailed
    case secureStorageCleanupFailed
}

nonisolated enum SessionAvailability: Equatable, Sendable {
    case validating
    case online
    case offline(SessionOfflineReason)
}

nonisolated enum SessionOfflineReason: Equatable, Sendable {
    case transport
    case serverUnavailable
    case rateLimited
    case responseInvalid
    case secureStorageWriteFailed
}
