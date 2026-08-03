import SwiftUI

struct SettingsView: View {
    private let router: FlowRouter
    @State private var viewModel: SettingsViewModel

    init(
        router: FlowRouter,
        dependencies: SettingsDependencies
    ) {
        self.router = router
        _viewModel = State(
            initialValue: SettingsViewModel(
                router: router,
                authenticationActions: router,
                appInfo: dependencies.appInfo
            )
        )
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        List {
            Section("App") {
                LabeledContent {
                    Text(verbatim: viewModel.model.displayName)
                } label: {
                    Text("Name")
                }
                LabeledContent {
                    Text(verbatim: viewModel.model.version)
                } label: {
                    Text("Version")
                }

                #if os(macOS)
                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                }
                .accessibilityIdentifier("action.openSettingsWindow")
                #endif
            }

            Section("Session") {
                Text("The demo authenticated flag is persisted without credentials or tokens.")

                Button("Session Info", systemImage: "info.circle") {
                    viewModel.openSessionInfo()
                }

                Button("Sign Out") {
                    viewModel.returnToAuthentication()
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
                SessionInfoView()
            }
        }
        .accessibilityIdentifier("screen.settings")
    }
}
