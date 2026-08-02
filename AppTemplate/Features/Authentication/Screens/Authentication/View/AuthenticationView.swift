import SwiftUI

struct AuthenticationView: View {
    @State private var viewModel: AuthenticationViewModel

    init(
        router: FlowRouter,
        authenticationCancellation: any IAuthenticationCancellation
    ) {
        _viewModel = State(
            initialValue: AuthenticationViewModel(
                router: router,
                authenticationActions: router,
                authenticationCancellation: authenticationCancellation
            )
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.badge.key")
                .font(.largeTitle)
            Text("Authentication")
                .font(.title)
            Text("Continue saves a demo authenticated flag. No credentials are stored.")
                .foregroundStyle(.secondary)
            HStack {
                Button("Cancel") {
                    viewModel.cancelAuthentication()
                }
                Button("Help") {
                    viewModel.openHelp()
                }
                Button("Continue") {
                    viewModel.continueToApp()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .navigationDestination(for: AuthenticationRoute.self) { route in
            switch route {
            case .help:
                AuthenticationHelpView()
            }
        }
    }
}
