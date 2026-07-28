nonisolated protocol ISessionService: Sendable {
    func currentSession() async throws -> UserSession?
    func signIn() async throws -> UserSession
    func signOut() async throws
}
