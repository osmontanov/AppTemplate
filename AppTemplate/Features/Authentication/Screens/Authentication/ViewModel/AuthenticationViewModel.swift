import Foundation
import Observation

@MainActor
@Observable
final class AuthenticationViewModel {
    private let session: any ISessionActions
    private let cancellation: any IAuthenticationCancellation
    private var model = AuthenticationModel(username: "", password: "")

    private(set) var state: AuthenticationState = .editing(
        AuthenticationModel(username: "", password: "")
    )
    private(set) var isBusy = false

    var username: String {
        get { model.username }
        set {
            guard !isBusy, newValue != model.username else { return }
            model.username = newValue
            state = .editing(model)
        }
    }

    var password: String {
        get { model.password }
        set {
            guard !isBusy, newValue != model.password else { return }
            model.password = newValue
            state = .editing(model)
        }
    }

    init(
        session: any ISessionActions,
        cancellation: any IAuthenticationCancellation
    ) {
        self.session = session
        self.cancellation = cancellation
    }

    func fillDemoCredentials() {
        guard !isBusy else { return }
        model = AuthenticationModel(username: "emilys", password: "emilyspass")
        state = .editing(model)
    }

    func submit() async {
        guard !isBusy else { return }
        let submitted = model
        guard !submitted.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !submitted.password.isEmpty else {
            state = .invalidCredentials(submitted)
            return
        }

        isBusy = true
        defer { isBusy = false }
        model = AuthenticationModel(username: submitted.username, password: "")
        state = .submitting(username: submitted.username)

        switch await session.login(
            username: submitted.username,
            password: submitted.password
        ) {
        case .authenticated:
            return
        case .cancelled:
            model = submitted
            state = .editing(submitted)
        case .failure(.invalidCredentials):
            model = submitted
            state = .invalidCredentials(submitted)
        case let .failure(.persistenceFailed(token)):
            state = .persistenceFailed(AuthenticationRetryContext(
                username: submitted.username,
                token: token
            ))
        case let .failure(failure):
            state = .failed(username: submitted.username, failure: failure)
        }
    }

    func retryPersistence() async {
        guard !isBusy,
              case let .persistenceFailed(context) = state else {
            return
        }

        isBusy = true
        defer { isBusy = false }
        switch await session.retryPersistence(context.token) {
        case .committed:
            return
        case let .failed(newToken, retained: _):
            state = .persistenceFailed(AuthenticationRetryContext(
                username: context.username,
                token: newToken
            ))
        case .invalidToken, .cancelled:
            model = AuthenticationModel(username: context.username, password: "")
            state = .editing(model)
        }
    }

    func cancel() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        if case let .persistenceFailed(context) = state {
            await session.discardPersistenceRetry(context.token)
        }
        cancellation.cancelAuthentication()
    }
}
