import Observation

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

@MainActor
@Observable
final class SessionStore {
    private(set) var phase: SessionPhase = .idle
    private(set) var failure: SessionFailure?

    private let service: any SessionService
    private var hasStarted = false

    init(service: any SessionService) {
        self.service = service
    }

    func start() async {
        guard !hasStarted else {
            return
        }
        hasStarted = true
        phase = .loading
        failure = nil

        do {
            if let session = try await service.currentSession() {
                phase = .authenticated(session)
            } else {
                phase = .unauthenticated
            }
        } catch is CancellationError {
            hasStarted = false
            phase = .idle
        } catch {
            phase = .unauthenticated
            failure = .restoration
        }
    }

    func retryStart() async {
        hasStarted = false
        await start()
    }

    func signIn() async {
        hasStarted = true
        phase = .loading
        failure = nil
        do {
            phase = .authenticated(try await service.signIn())
        } catch is CancellationError {
            phase = .unauthenticated
        } catch {
            phase = .unauthenticated
            failure = .signIn
        }
    }

    func signOut() async {
        hasStarted = true
        let previousPhase = phase
        phase = .loading
        failure = nil
        do {
            try await service.signOut()
            phase = .unauthenticated
        } catch is CancellationError {
            phase = previousPhase
        } catch {
            phase = previousPhase
            failure = .signOut
        }
    }
}
