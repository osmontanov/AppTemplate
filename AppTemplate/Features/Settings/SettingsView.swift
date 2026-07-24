import SwiftUI

struct SettingsNavigationView: View {
    @Bindable var router: SettingsRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            List {
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
