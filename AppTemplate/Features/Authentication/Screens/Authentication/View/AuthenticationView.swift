import SwiftUI

struct AuthenticationView: View {
    @State private var viewModel: AuthenticationViewModel

    init(router: FlowRouter) {
        _viewModel = State(
            initialValue: AuthenticationViewModel(router: router)
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.badge.key")
                .font(.largeTitle)
            Text("Authentication")
                .font(.title)
            Text("Use this screen as a navigation-only authentication entry.")
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
