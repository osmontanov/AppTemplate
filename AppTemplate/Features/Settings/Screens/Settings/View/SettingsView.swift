import SwiftUI

struct SettingsView: View {
    private let router: FlowRouter
    @State private var viewModel: SettingsViewModel

    init(
        router: FlowRouter,
        sessionStore: SessionStore
    ) {
        self.router = router
        _viewModel = State(
            initialValue: SettingsViewModel(
                sessionStore: sessionStore,
                router: router
            )
        )
    }

    var body: some View {
        List {
            Section("Session") {
                switch viewModel.phase {
                case let .authenticated(session):
                    LabeledContent("Signed in", value: session.displayName)
                    Button("Sign Out") {
                        Task { await viewModel.signOut() }
                    }
                case .idle, .loading:
                    ProgressView()
                case .unauthenticated:
                    Text("Not signed in")
                }

                if let failureMessage = viewModel.failureMessage {
                    Text(failureMessage)
                        .foregroundStyle(.secondary)
                }
            }

            Button("About this template") {
                viewModel.openAbout()
            }
        }
        .navigationTitle("Settings")
        .navigationDestination(for: SettingsRoute.self) { route in
            switch route {
            case .about:
                AboutView()
            }
        }
    }
}
