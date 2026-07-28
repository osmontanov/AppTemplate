import SwiftUI

struct SettingsNavigationView: View {
    @Bindable var router: SettingsRouter
    @State private var viewModel: SettingsViewModel

    init(
        router: SettingsRouter,
        sessionStore: SessionStore
    ) {
        self.router = router
        _viewModel = State(
            initialValue: SettingsViewModel(
                sessionStore: sessionStore
            )
        )
    }

    var body: some View {
        NavigationStack(path: $router.path) {
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

                NavigationLink("About this template", value: SettingsRoute.about)
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
}
