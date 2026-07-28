import SwiftUI

struct AuthenticationView: View {
    @State private var viewModel: AuthenticationViewModel

    init(
        sessionStore: SessionStore,
        router: AppRouter
    ) {
        _viewModel = State(
            initialValue: AuthenticationViewModel(
                sessionStore: sessionStore,
                router: router
            )
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.badge.key")
                .font(.largeTitle)
            Text("Authentication")
                .font(.title)
            Text("Connect the project’s session service here.")
                .foregroundStyle(.secondary)
            if let failureMessage = viewModel.failureMessage {
                Text(failureMessage)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button("Cancel") {
                    viewModel.cancelAuthentication()
                }
                if viewModel.canRetryRestoration {
                    Button("Retry") {
                        Task {
                            await viewModel.retryRestoration()
                        }
                    }
                }
                Button("Continue") {
                    Task {
                        await viewModel.signIn()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
