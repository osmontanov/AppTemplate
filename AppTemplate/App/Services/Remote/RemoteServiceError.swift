nonisolated
enum RemoteServiceError: Error, Equatable, Sendable {
    case cancelled
    case transport
    case status(code: Int, authenticationError: AuthErrorDTO?)
    case invalidResponse
}
