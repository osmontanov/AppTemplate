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
}
