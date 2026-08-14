nonisolated
struct AuthenticationRetryContext: Equatable, Sendable {
    let username: String
    let token: SessionPersistenceRetryToken
}

nonisolated
enum AuthenticationState:
    Equatable,
    Sendable,
    CustomStringConvertible {
    case editing(AuthenticationModel)
    case submitting(username: String)
    case invalidCredentials(AuthenticationModel)
    case persistenceFailed(AuthenticationRetryContext)
    case failed(username: String, failure: SessionLoginFailure)

    var description: String {
        switch self {
        case let .editing(model):
            "AuthenticationState.editing(\(model))"
        case let .submitting(username):
            "AuthenticationState.submitting(" +
                "username: \(username), password: <redacted>)"
        case let .invalidCredentials(model):
            "AuthenticationState.invalidCredentials(\(model))"
        case let .persistenceFailed(context):
            "AuthenticationState.persistenceFailed(" +
                "username: \(context.username), password: <redacted>, " +
                "token: <redacted>)"
        case let .failed(username, failure):
            "AuthenticationState.failed(" +
                "username: \(username), password: <redacted>, " +
                "failure: \(failureDescription(failure)))"
        }
    }

    private func failureDescription(_ failure: SessionLoginFailure) -> String {
        switch failure {
        case .invalidCredentials: "invalidCredentials"
        case .transport: "transport"
        case .serverUnavailable: "serverUnavailable"
        case .rateLimited: "rateLimited"
        case .responseInvalid: "responseInvalid"
        case .persistenceFailed: "persistenceFailed(<redacted>)"
        case .concurrentAttempt: "concurrentAttempt"
        }
    }
}
