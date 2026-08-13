nonisolated enum AuthEndpoint: Sendable {
    case login
    case me
    case refresh
}

nonisolated enum AuthFailureDisposition: Equatable, Sendable {
    case invalidCredentials
    case refreshRequired
    case credentialsRejected
    case transport
    case serverUnavailable
    case rateLimited
    case responseInvalid
    case cancelled
}

nonisolated enum AuthenticationResponseClassifier {
    static func classify(
        _ error: RemoteServiceError,
        endpoint: AuthEndpoint
    ) -> AuthFailureDisposition {
        switch error {
        case .cancelled:
            return .cancelled
        case .transport:
            return .transport
        case .invalidResponse:
            return .responseInvalid
        case let .status(code, _) where code == 408 || (500...599).contains(code):
            return .serverUnavailable
        case .status(429, _):
            return .rateLimited
        case let .status(code, authenticationError):
            guard authenticationError != nil else {
                return .responseInvalid
            }

            switch (endpoint, code) {
            case (.login, 400), (.login, 401), (.login, 403):
                return .invalidCredentials
            case (.me, 401), (.me, 403):
                return .refreshRequired
            case (.refresh, 400), (.refresh, 401), (.refresh, 403):
                return .credentialsRejected
            default:
                return .responseInvalid
            }
        }
    }
}
