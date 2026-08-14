import Foundation
import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct AuthenticationViewModelTests {
    @Test
    func blankCredentialsAreRejectedWithoutStartingLogin() async {
        let session = SessionActionsSpy()
        let viewModel = AuthenticationViewModel(
            session: session,
            cancellation: AuthenticationCancellationSpy()
        )
        viewModel.username = "   "
        viewModel.password = ""

        await viewModel.submit()

        #expect(session.loginCalls.isEmpty)
        #expect(
            viewModel.state == .invalidCredentials(
                AuthenticationModel(username: "   ", password: "")
            )
        )
    }

    @Test
    func demoCredentialsFillTheEditableModel() {
        let viewModel = AuthenticationViewModel(
            session: SessionActionsSpy(),
            cancellation: AuthenticationCancellationSpy()
        )

        viewModel.fillDemoCredentials()

        #expect(viewModel.username == "emilys")
        #expect(viewModel.password == "emilyspass")
        #expect(
            viewModel.state == .editing(
                AuthenticationModel(username: "emilys", password: "emilyspass")
            )
        )
    }

    @Test
    func modelAndStateDescriptionsAlwaysRedactPassword() {
        let secret = "never-print-this"
        let model = AuthenticationModel(username: "emilys", password: secret)
        let token = SessionPersistenceRetryToken()
        let states: [AuthenticationState] = [
            .editing(model),
            .submitting(username: "emilys"),
            .invalidCredentials(model),
            .persistenceFailed(AuthenticationRetryContext(username: "emilys", token: token)),
            .failed(username: "emilys", failure: .transport)
        ]

        #expect(model.description.contains("password: <redacted>"))
        #expect(!model.description.contains(secret))
        for state in states {
            #expect(state.description.contains("password: <redacted>"))
            #expect(!state.description.contains(secret))
        }
    }

    @Test
    func invalidCredentialsRetainEditableCredentialsForCorrection() async {
        let session = SessionActionsSpy(loginResults: [.failure(.invalidCredentials)])
        let viewModel = AuthenticationViewModel(
            session: session,
            cancellation: AuthenticationCancellationSpy()
        )
        viewModel.username = "emilys"
        viewModel.password = "wrong"

        await viewModel.submit()

        #expect(
            viewModel.state == .invalidCredentials(
                AuthenticationModel(username: "emilys", password: "wrong")
            )
        )
        #expect(viewModel.password == "wrong")
    }

    @Test
    func equivalentFieldWritesPreserveInvalidCredentialsUntilContentChanges() async {
        let session = SessionActionsSpy(loginResults: [.failure(.invalidCredentials)])
        let viewModel = AuthenticationViewModel(
            session: session,
            cancellation: AuthenticationCancellationSpy()
        )
        viewModel.username = "emilys"
        viewModel.password = "wrong"
        await viewModel.submit()

        viewModel.username = "emilys"
        viewModel.password = "wrong"

        #expect(
            viewModel.state == .invalidCredentials(
                AuthenticationModel(username: "emilys", password: "wrong")
            )
        )

        viewModel.password = "corrected"

        #expect(
            viewModel.state == .editing(
                AuthenticationModel(username: "emilys", password: "corrected")
            )
        )
    }

    @Test
    func cancelledLoginRestoresEditingCredentials() async {
        let session = SessionActionsSpy(loginResults: [.cancelled])
        let viewModel = AuthenticationViewModel(
            session: session,
            cancellation: AuthenticationCancellationSpy()
        )
        viewModel.username = "emilys"
        viewModel.password = "emilyspass"

        await viewModel.submit()

        #expect(
            viewModel.state == .editing(
                AuthenticationModel(username: "emilys", password: "emilyspass")
            )
        )
    }

    @Test
    func authenticatedLoginReliesOnSessionPublicationWithoutCancellingScene() async {
        let session = SessionActionsSpy(loginResults: [.authenticated(authenticatedSnapshot())])
        let cancellation = AuthenticationCancellationSpy()
        let viewModel = AuthenticationViewModel(
            session: session,
            cancellation: cancellation
        )
        viewModel.username = "emilys"
        viewModel.password = "emilyspass"

        await viewModel.submit()

        #expect(viewModel.state == .submitting(username: "emilys"))
        #expect(viewModel.password.isEmpty)
        #expect(cancellation.callCount == 0)
    }

    @Test(arguments: [
        SessionLoginFailure.transport,
        .serverUnavailable,
        .rateLimited,
        .responseInvalid,
        .concurrentAttempt
    ])
    func nonCredentialFailureClearsPassword(
        failure: SessionLoginFailure
    ) async {
        let session = SessionActionsSpy(loginResults: [.failure(failure)])
        let viewModel = AuthenticationViewModel(
            session: session,
            cancellation: AuthenticationCancellationSpy()
        )
        viewModel.username = "emilys"
        viewModel.password = "emilyspass"

        await viewModel.submit()

        #expect(viewModel.state == .failed(username: "emilys", failure: failure))
        #expect(viewModel.password.isEmpty)
        #expect(!String(describing: viewModel.state).contains("emilyspass"))
    }

    @Test
    func persistenceRetryKeepsUsernameButNotPassword() async {
        let token = SessionPersistenceRetryToken()
        let snapshot = authenticatedSnapshot()
        let session = SessionActionsSpy(
            loginResults: [.failure(.persistenceFailed(token))],
            retryResults: [.committed(snapshot)]
        )
        let viewModel = AuthenticationViewModel(
            session: session,
            cancellation: AuthenticationCancellationSpy()
        )
        viewModel.username = "emilys"
        viewModel.password = "emilyspass"

        await viewModel.submit()

        #expect(
            viewModel.state == .persistenceFailed(
                AuthenticationRetryContext(username: "emilys", token: token)
            )
        )
        #expect(viewModel.password.isEmpty)
        #expect(!String(describing: viewModel.state).contains("emilyspass"))

        await viewModel.retryPersistence()

        #expect(session.loginCalls.count == 1)
        #expect(session.retryCalls == [token])
    }

    @Test
    func failedPersistenceRetryReplacesOnlyTheToken() async {
        let original = SessionPersistenceRetryToken()
        let replacement = SessionPersistenceRetryToken()
        let retained = authenticatedSnapshot()
        let session = SessionActionsSpy(
            loginResults: [.failure(.persistenceFailed(original))],
            retryResults: [.failed(replacement, retained: retained)]
        )
        let viewModel = AuthenticationViewModel(
            session: session,
            cancellation: AuthenticationCancellationSpy()
        )
        viewModel.username = "emilys"
        viewModel.password = "emilyspass"
        await viewModel.submit()

        await viewModel.retryPersistence()

        #expect(
            viewModel.state == .persistenceFailed(
                AuthenticationRetryContext(username: "emilys", token: replacement)
            )
        )
        #expect(viewModel.password.isEmpty)
        #expect(session.loginCalls.count == 1)
        #expect(session.retryCalls == [original])
    }

    @Test(arguments: [
        SessionPersistenceRetryResult.invalidToken,
        .cancelled
    ])
    func terminalPersistenceRetryReturnsToNonSecretEditing(
        result: SessionPersistenceRetryResult
    ) async {
        let token = SessionPersistenceRetryToken()
        let session = SessionActionsSpy(
            loginResults: [.failure(.persistenceFailed(token))],
            retryResults: [result]
        )
        let viewModel = AuthenticationViewModel(
            session: session,
            cancellation: AuthenticationCancellationSpy()
        )
        viewModel.username = "emilys"
        viewModel.password = "emilyspass"
        await viewModel.submit()

        await viewModel.retryPersistence()

        #expect(
            viewModel.state == .editing(
                AuthenticationModel(username: "emilys", password: "")
            )
        )
        #expect(viewModel.password.isEmpty)
        #expect(session.loginCalls.count == 1)
    }

    @Test
    func concurrentSubmitStartsOnlyOneLogin() async {
        let gate = AuthenticationResultGate<SessionLoginResult>()
        let session = SessionActionsSpy(loginGate: gate)
        let viewModel = AuthenticationViewModel(
            session: session,
            cancellation: AuthenticationCancellationSpy()
        )
        viewModel.username = "emilys"
        viewModel.password = "emilyspass"

        let first = Task { await viewModel.submit() }
        await gate.waitUntilEntered()
        await viewModel.submit()

        #expect(session.loginCalls.count == 1)

        await gate.resolve(.cancelled)
        await first.value
    }

    @Test
    func concurrentPersistenceRetryStartsOnlyOneTokenRetry() async {
        let token = SessionPersistenceRetryToken()
        let gate = AuthenticationResultGate<SessionPersistenceRetryResult>()
        let session = SessionActionsSpy(
            loginResults: [.failure(.persistenceFailed(token))],
            retryGate: gate
        )
        let viewModel = AuthenticationViewModel(
            session: session,
            cancellation: AuthenticationCancellationSpy()
        )
        viewModel.username = "emilys"
        viewModel.password = "emilyspass"
        await viewModel.submit()

        let first = Task { await viewModel.retryPersistence() }
        await gate.waitUntilEntered()
        await viewModel.retryPersistence()

        #expect(session.retryCalls == [token])

        await gate.resolve(.cancelled)
        await first.value
    }

    @Test
    func cancelAwaitsRetryDiscardBeforeSceneCancellation() async {
        let token = SessionPersistenceRetryToken()
        let discardGate = AuthenticationVoidGate()
        let session = SessionActionsSpy(
            loginResults: [.failure(.persistenceFailed(token))],
            discardGate: discardGate
        )
        let cancellation = AuthenticationCancellationSpy()
        let viewModel = AuthenticationViewModel(
            session: session,
            cancellation: cancellation
        )
        viewModel.username = "emilys"
        viewModel.password = "emilyspass"
        await viewModel.submit()

        let cancellationTask = Task { await viewModel.cancel() }
        await discardGate.waitUntilEntered()

        #expect(session.discardCalls == [token])
        #expect(cancellation.callCount == 0)

        await discardGate.resolve()
        await cancellationTask.value

        #expect(cancellation.callCount == 1)
    }

    @Test
    func authenticationFlowAndScreenUseNarrowDependencies() {
        let dependencies = AuthenticationDependencies(
            session: SessionActionsSpy(),
            cancellation: AuthenticationCancellationSpy()
        )

        _ = AuthenticationView(dependencies: dependencies)
        _ = AuthenticationFlowView(dependencies: dependencies)
    }
}

@MainActor
private final class SessionActionsSpy: ISessionActions {
    private(set) var status = SessionStatusPresentation(
        session: SessionPresentation(state: .guest, revision: 1),
        expiry: nil
    )
    var presentation: SessionPresentation { status.session }
    private(set) var loginCalls: [(username: String, password: String)] = []
    private(set) var retryCalls: [SessionPersistenceRetryToken] = []
    private(set) var discardCalls: [SessionPersistenceRetryToken] = []

    private var loginResults: [SessionLoginResult]
    private var retryResults: [SessionPersistenceRetryResult]
    private let loginGate: AuthenticationResultGate<SessionLoginResult>?
    private let retryGate: AuthenticationResultGate<SessionPersistenceRetryResult>?
    private let discardGate: AuthenticationVoidGate?

    init(
        loginResults: [SessionLoginResult] = [],
        retryResults: [SessionPersistenceRetryResult] = [],
        loginGate: AuthenticationResultGate<SessionLoginResult>? = nil,
        retryGate: AuthenticationResultGate<SessionPersistenceRetryResult>? = nil,
        discardGate: AuthenticationVoidGate? = nil
    ) {
        self.loginResults = loginResults
        self.retryResults = retryResults
        self.loginGate = loginGate
        self.retryGate = retryGate
        self.discardGate = discardGate
    }

    func bootstrap() async {}
    func retryBootstrap() async {}

    func login(username: String, password: String) async -> SessionLoginResult {
        loginCalls.append((username, password))
        if let loginGate { return await loginGate.wait() }
        return loginResults.isEmpty ? .cancelled : loginResults.removeFirst()
    }

    func retryPersistence(
        _ token: SessionPersistenceRetryToken
    ) async -> SessionPersistenceRetryResult {
        retryCalls.append(token)
        if let retryGate { return await retryGate.wait() }
        return retryResults.isEmpty ? .cancelled : retryResults.removeFirst()
    }

    func discardPersistenceRetry(_ token: SessionPersistenceRetryToken) async {
        discardCalls.append(token)
        await discardGate?.wait()
    }

    func validateSession() async -> SessionValidationResult { .unchanged }
    func refreshSession() async -> SessionValidationResult { .unchanged }
    func signOut() async -> SessionSignOutResult { .cancelled }
}

@MainActor
private final class AuthenticationCancellationSpy: IAuthenticationCancellation {
    private(set) var callCount = 0

    func cancelAuthentication() {
        callCount += 1
    }
}

private actor AuthenticationResultGate<Value: Sendable> {
    private var entered = false
    private var result: Value?
    private var entryWaiters: [CheckedContinuation<Void, Never>] = []
    private var resultWaiters: [CheckedContinuation<Value, Never>] = []

    func wait() async -> Value {
        entered = true
        let pendingEntryWaiters = entryWaiters
        entryWaiters.removeAll()
        pendingEntryWaiters.forEach { $0.resume() }
        if let result { return result }
        return await withCheckedContinuation { resultWaiters.append($0) }
    }

    func waitUntilEntered() async {
        guard !entered else { return }
        await withCheckedContinuation { entryWaiters.append($0) }
    }

    func resolve(_ value: Value) {
        guard result == nil else { return }
        result = value
        let pendingResultWaiters = resultWaiters
        resultWaiters.removeAll()
        pendingResultWaiters.forEach { $0.resume(returning: value) }
    }
}

private actor AuthenticationVoidGate {
    private var entered = false
    private var resolved = false
    private var entryWaiters: [CheckedContinuation<Void, Never>] = []
    private var resultWaiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        entered = true
        let pendingEntryWaiters = entryWaiters
        entryWaiters.removeAll()
        pendingEntryWaiters.forEach { $0.resume() }
        guard !resolved else { return }
        await withCheckedContinuation { resultWaiters.append($0) }
    }

    func waitUntilEntered() async {
        guard !entered else { return }
        await withCheckedContinuation { entryWaiters.append($0) }
    }

    func resolve() {
        resolved = true
        let pendingResultWaiters = resultWaiters
        resultWaiters.removeAll()
        pendingResultWaiters.forEach { $0.resume() }
    }
}

private func authenticatedSnapshot() -> SessionRepositorySnapshot {
    SessionRepositorySnapshot(
        state: .authenticated(
            UserProfile(
                id: 1,
                username: "emilys",
                firstName: "Emily",
                lastName: "Johnson",
                imageURL: nil
            ),
            availability: .online
        ),
        expiry: nil
    )
}
