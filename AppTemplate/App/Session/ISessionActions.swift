@MainActor
protocol ISessionActions: AnyObject {
    var status: SessionStatusPresentation { get }
    var presentation: SessionPresentation { get }
    func bootstrap() async
    func retryBootstrap() async
    func login(username: String, password: String) async -> SessionLoginResult
    func retryPersistence(
        _ token: SessionPersistenceRetryToken
    ) async -> SessionPersistenceRetryResult
    func discardPersistenceRetry(_ token: SessionPersistenceRetryToken) async
    func validateSession() async -> SessionValidationResult
    func refreshSession() async -> SessionValidationResult
    func signOut() async -> SessionSignOutResult
}
