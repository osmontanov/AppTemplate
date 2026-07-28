nonisolated enum SessionPhase: Equatable, Sendable {
    case idle
    case loading
    case unauthenticated
    case authenticated(UserSession)
}

nonisolated enum SessionFailure: Equatable, Sendable {
    case restoration
    case signIn
    case signOut

    var message: String {
        switch self {
        case .restoration:
            "The previous session could not be restored."
        case .signIn:
            "Sign in could not be completed."
        case .signOut:
            "Sign out could not be completed."
        }
    }
}
