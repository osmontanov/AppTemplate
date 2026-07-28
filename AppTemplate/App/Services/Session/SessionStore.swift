import Observation

@MainActor
@Observable
final class SessionStore {
    private(set) var phase: SessionPhase = .idle
    private(set) var failure: SessionFailure?

    private let service: any ISessionService
    private var commandVersion = 0
    private var stablePhase: SessionPhase = .idle
    private var startupTask: Task<Void, Never>?
    private var activeRestoration: ActiveRestoration?

    private struct ActiveRestoration {
        let version: Int
        let task: Task<Void, Never>
    }

    private enum RestorationOutcome {
        case restored(UserSession?)
        case cancelled
        case failed
    }

    init(service: any ISessionService) {
        self.service = service
    }

    func start() async {
        if let startupTask {
            await startupTask.value
            return
        }

        let task = beginRestoration()
        startupTask = task
        await task.value
    }

    func retryStart() async {
        if let activeRestoration,
           activeRestoration.version == commandVersion {
            await activeRestoration.task.value
            return
        }

        await beginRestoration().value
    }

    func signIn() async {
        let version = beginCommand()

        do {
            let session = try await service.signIn()
            guard version == commandVersion else {
                return
            }
            publish(.authenticated(session))
        } catch is CancellationError {
            guard version == commandVersion else {
                return
            }
            publish(.unauthenticated)
        } catch {
            guard version == commandVersion else {
                return
            }
            publish(.unauthenticated)
            failure = .signIn
        }
    }

    func signOut() async {
        let previousPhase = stablePhase
        let version = beginCommand()

        do {
            try await service.signOut()
            guard version == commandVersion else {
                return
            }
            publish(.unauthenticated)
        } catch is CancellationError {
            guard version == commandVersion else {
                return
            }
            publish(previousPhase)
        } catch {
            guard version == commandVersion else {
                return
            }
            publish(previousPhase)
            failure = .signOut
        }
    }

    private func beginRestoration() -> Task<Void, Never> {
        let version = beginCommand()
        let service = service
        let task = Task { @MainActor [weak self, service] in
            let outcome: RestorationOutcome
            do {
                outcome = .restored(try await service.currentSession())
            } catch is CancellationError {
                outcome = .cancelled
            } catch {
                outcome = .failed
            }

            self?.finishRestoration(outcome, version: version)
        }
        activeRestoration = ActiveRestoration(version: version, task: task)
        return task
    }

    private func beginCommand() -> Int {
        commandVersion += 1
        phase = .loading
        failure = nil
        return commandVersion
    }

    private func finishRestoration(
        _ outcome: RestorationOutcome,
        version: Int
    ) {
        if activeRestoration?.version == version {
            activeRestoration = nil
        }
        guard version == commandVersion else {
            return
        }

        switch outcome {
        case let .restored(session):
            if let session {
                publish(.authenticated(session))
            } else {
                publish(.unauthenticated)
            }
        case .cancelled:
            publish(.idle)
        case .failed:
            publish(.unauthenticated)
            failure = .restoration
        }
    }

    private func publish(_ phase: SessionPhase) {
        stablePhase = phase
        self.phase = phase
    }
}
