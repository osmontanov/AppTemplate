import SwiftUI

struct SettingsNavigationView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Bindable var router: SettingsRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            List {
                Section("Session") {
                    switch sessionStore.phase {
                    case let .authenticated(session):
                        LabeledContent("Signed in", value: session.displayName)
                        Button("Sign Out") {
                            Task { await sessionStore.signOut() }
                        }
                    case .idle, .loading:
                        ProgressView()
                    case .unauthenticated:
                        Text("Not signed in")
                    }

                    if let failure = sessionStore.failure {
                        Text(failure.message)
                            .foregroundStyle(.secondary)
                    }
                }

                NavigationLink("About this template", value: SettingsRoute.about)
            }
            .navigationTitle("Settings")
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .about:
                    AboutTemplateView()
                }
            }
        }
    }
}

private struct AboutTemplateView: View {
    var body: some View {
        List {
            Section("Platforms") {
                Text("iOS 26")
                Text("iPadOS 26")
                Text("macOS 26")
            }
            Section("Examples") {
                Text("Home, Browse, and Settings are replaceable feature examples.")
            }
        }
        .navigationTitle("About")
    }
}
