import SwiftUI

struct AuthenticationView: View {
    private enum Field: Hashable { case username, password, result }

    @State private var viewModel: AuthenticationViewModel
    @FocusState private var focusedField: Field?
    @AccessibilityFocusState private var accessibilityFocusedField: Field?

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
                Text(AppText.resource("Sign in"))
                    .font(.title)
                content
                navigationActions
            }
        }
        .navigationTitle(AppText.resource("Authentication"))
        .frame(minWidth: 360, minHeight: 420)
        .accessibilityIdentifier(AppAccessibilityIdentifier.screen(.authentication))
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .editing:
            credentialsForm(message: nil)
        case .invalidCredentials:
            credentialsForm(message: AppText.string("Check your username and password."))
        case let .submitting(username):
            ProgressView(AppText.resource("Signing in as \(username)"))
                .accessibilityLabel(AppText.resource("Signing in"))
                .accessibilityIdentifier(AppAccessibilityIdentifier.result(.loading))
        case let .persistenceFailed(context):
            VStack(spacing: 12) {
                Text(AppText.resource("Signed in as \(context.username), but the session could not be saved."))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(AppText.resource("Signed in, but the session could not be saved."))
                    .accessibilityFocused($accessibilityFocusedField, equals: .result)
                    .accessibilityIdentifier(AppAccessibilityIdentifier.result(.actualFailure))
                Button(AppText.resource("Retry saving session")) {
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
            TextField(AppText.resource("Username"), text: Binding(
                get: { viewModel.username },
                set: { viewModel.username = $0 }
            ))
            .textContentType(.username)
            .focused($focusedField, equals: .username)
            .accessibilityFocused($accessibilityFocusedField, equals: .username)
            .accessibilityIdentifier("authentication.username")
            SecureField(AppText.resource("Password"), text: Binding(
                get: { viewModel.password },
                set: { viewModel.password = $0 }
            ))
            .textContentType(.password)
            .focused($focusedField, equals: .password)
            .accessibilityFocused($accessibilityFocusedField, equals: .password)
            .accessibilityIdentifier("authentication.password")
            if let message {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(AppText.resource("Sign in failed. Check your entries and try again."))
                    .accessibilityFocused($accessibilityFocusedField, equals: .result)
                    .accessibilityIdentifier(AppAccessibilityIdentifier.result(.actualFailure))
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
        Button(AppText.resource("Use demo credentials")) {
            viewModel.fillDemoCredentials()
        }
        .accessibilityIdentifier("action.authentication.demo-credentials")
        Button(AppText.resource("Sign in")) {
            Task { await submit() }
        }
        .buttonStyle(.borderedProminent)
        .frame(minHeight: 44)
        .keyboardShortcut(.defaultAction)
        .accessibilityIdentifier(AppAccessibilityIdentifier.action(.signIn))
    }

    private var navigationActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack { modalActions }
            VStack { modalActions }
        }
    }

    @ViewBuilder
    private var modalActions: some View {
        Button(AppText.resource("Cancel")) {
            Task { await viewModel.cancel() }
        }
        .disabled(viewModel.isBusy)
        .frame(minHeight: 44)
        .keyboardShortcut(.cancelAction)
        .accessibilityIdentifier(AppAccessibilityIdentifier.action(.cancel))
        NavigationLink(AppText.resource("Help"), value: AuthenticationRoute.help)
    }

    private func failureMessage(
        username: String,
        failure: SessionLoginFailure
    ) -> String {
        switch failure {
        case .transport:
            AppText.string(
                "authentication.networkUnavailable",
                defaultValue: "The network is unavailable for \(username)."
            )
        case .serverUnavailable:
            AppText.string("The sign-in service is unavailable.")
        case .rateLimited:
            AppText.string("Too many attempts. Try again later.")
        case .responseInvalid:
            AppText.string("The sign-in response was invalid.")
        case .concurrentAttempt:
            AppText.string("Another sign-in attempt is already running.")
        case .invalidCredentials:
            AppText.string("Check your username and password.")
        case .persistenceFailed:
            AppText.string("The session could not be saved.")
        }
    }

    private func submit() async {
        await viewModel.submit()
        switch viewModel.state {
        case .invalidCredentials, .failed:
            focusedField = .username
            accessibilityFocusedField = .username
            AccessibilityNotification.Announcement(
                AppText.string("Sign in failed. Check your entries and try again.")
            ).post()
        case .persistenceFailed:
            accessibilityFocusedField = .result
            AccessibilityNotification.Announcement(
                AppText.string("The session could not be saved.")
            ).post()
        case .editing, .submitting:
            break
        }
    }
}

#Preview("Accessibility Size") {
    PreviewFixtures.authenticationFlow()
        .environment(\.dynamicTypeSize, .accessibility5)
}
