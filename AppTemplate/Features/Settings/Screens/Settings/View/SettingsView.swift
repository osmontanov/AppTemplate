import SwiftUI

struct SettingsView: View {
    private let router: FlowRouter
    private let sessionStore: SessionStore
    @State private var viewModel: SettingsViewModel

    init(
        router: FlowRouter,
        sessionStore: SessionStore
    ) {
        self.router = router
        self.sessionStore = sessionStore
        _viewModel = State(
            initialValue: SettingsViewModel(
                sessionStore: sessionStore,
                router: router
            )
        )
    }

    var body: some View {
        @Bindable var viewModel = viewModel

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

                Button("Session Info", systemImage: "info.circle") {
                    viewModel.openSessionInfo()
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
                AboutView(router: router)
            }
        }
        .sheet(item: $viewModel.sheet, onDismiss: {
            viewModel.dismissSheet()
        }) { route in
            switch route {
            case .sessionInfo:
                SessionInfoView(sessionStore: sessionStore)
            }
        }
    }
}
