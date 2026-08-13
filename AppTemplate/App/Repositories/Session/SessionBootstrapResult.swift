import Foundation

nonisolated enum SessionBootstrapReadResult: Equatable, Sendable {
    case candidateReady
    case readFailed
    case staleAttempt
}

nonisolated enum SessionBootstrapRaceWinner: Equatable, Sendable {
    case read(SessionBootstrapReadResult)
    case timeout
}

nonisolated struct SessionExpiryPresentation: Equatable, Sendable {
    let accessExpiresAt: Date?
    let refreshExpiresAt: Date?
}

nonisolated struct SessionRepositorySnapshot: Equatable, Sendable {
    let state: SessionState
    let expiry: SessionExpiryPresentation?
}
