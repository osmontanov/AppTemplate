import SwiftUI

struct AuthenticationView: View {
    @State private var viewModel: AuthenticationViewModel

    init(dependencies: AuthenticationDependencies) {
        _viewModel = State(initialValue: AuthenticationViewModel(
            session: dependencies.session,
            cancellation: dependencies.cancellation
        ))
    }

    var body: some View {
        AdaptiveContentContainer {
            VStack(spacing: 16) {
                Image(systemName: "person.badge.key")
                    .font(.largeTitle)
                    .accessibilityHidden(true)
                Text(StoreServicesText.resource("Sign in"))
                    .font(.title)
                content
                navigationActions
            }
        }
        .navigationTitle(StoreServicesText.resource("Authentication"))
        .frame(minWidth: 360, minHeight: 420)
        .accessibilityIdentifier("screen.authentication")
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .editing:
            credentialsForm(message: nil)
        case .invalidCredentials:
            credentialsForm(message: StoreServicesText.string("Check your username and password."))
        case let .submitting(username):
            ProgressView(StoreServicesText.resource("Signing in as \(username)"))
        case let .persistenceFailed(context):
            VStack(spacing: 12) {
                Text(StoreServicesText.resource("Signed in as \(context.username), but the session could not be saved."))
                    .foregroundStyle(.secondary)
                Button(StoreServicesText.resource("Retry saving session")) {
                    Task { await viewModel.retryPersistence() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isBusy)
            }
        case let .failed(username, failure):
            credentialsForm(message: failureMessage(username: username, failure: failure))
        }
    }

    private func credentialsForm(message: String?) -> some View {
        VStack(spacing: 12) {
            TextField(StoreServicesText.resource("Username"), text: Binding(
                get: { viewModel.username },
                set: { viewModel.username = $0 }
            ))
            .textContentType(.username)
            .accessibilityIdentifier("authentication.username")
            SecureField(StoreServicesText.resource("Password"), text: Binding(
                get: { viewModel.password },
                set: { viewModel.password = $0 }
            ))
            .textContentType(.password)
            .accessibilityIdentifier("authentication.password")
            if let message {
                Text(message)
                    .foregroundStyle(.red)
            }
            ViewThatFits(in: .horizontal) {
                HStack { credentialActions }
                VStack { credentialActions }
            }
        }
        .disabled(viewModel.isBusy)
    }

    @ViewBuilder
    private var credentialActions: some View {
        Button(StoreServicesText.resource("Use demo credentials")) {
            viewModel.fillDemoCredentials()
        }
        Button(StoreServicesText.resource("Sign in")) {
            Task { await viewModel.submit() }
        }
        .buttonStyle(.borderedProminent)
    }

    private var navigationActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack { modalActions }
            VStack { modalActions }
        }
    }

    @ViewBuilder
    private var modalActions: some View {
        Button(StoreServicesText.resource("Cancel")) {
            Task { await viewModel.cancel() }
        }
        .disabled(viewModel.isBusy)
        NavigationLink(StoreServicesText.resource("Help"), value: AuthenticationRoute.help)
    }

    private func failureMessage(
        username: String,
        failure: SessionLoginFailure
    ) -> String {
        switch failure {
        case .transport:
            StoreServicesText.string(
                "authentication.networkUnavailable",
                defaultValue: "The network is unavailable for \(username)."
            )
        case .serverUnavailable:
            StoreServicesText.string("The sign-in service is unavailable.")
        case .rateLimited:
            StoreServicesText.string("Too many attempts. Try again later.")
        case .responseInvalid:
            StoreServicesText.string("The sign-in response was invalid.")
        case .concurrentAttempt:
            StoreServicesText.string("Another sign-in attempt is already running.")
        case .invalidCredentials:
            StoreServicesText.string("Check your username and password.")
        case .persistenceFailed:
            StoreServicesText.string("The session could not be saved.")
        }
    }
}

#Preview("Accessibility Size") {
    PreviewFixtures.authenticationFlow()
        .environment(\.dynamicTypeSize, .accessibility5)
}
