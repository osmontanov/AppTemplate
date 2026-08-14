import SwiftUI

struct ServicesFlowView: View {
    @Bindable var router: ServicesRouter
    let session: SessionPresentation
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        AdaptiveFlowNavigationContainer(
            path: $router.path,
            layout: AdaptiveFlowLayoutPolicy.resolve(horizontalSizeClass: horizontalSizeClass, isMacOS: isMacOS)
        ) {
            List(services, id: \.route) { item in
                NavigationLink(item.title, value: item.route)
            }
            .navigationTitle("Services")
            .accessibilityIdentifier("screen.services.root")
        } placeholder: {
            ContentUnavailableView("Select a Service", systemImage: "wrench.and.screwdriver")
        } destination: { route in
            ContentUnavailableView(title(for: route), systemImage: "wrench.and.screwdriver")
                .navigationTitle(title(for: route))
        }
    }

    private var services: [(route: ServicesRoute, title: String)] {
        [
            (.appState, "App State"), (.appInfo, "App Info"),
            (.userDefaults, "UserDefaults"), (.keychain, "Keychain"),
            (.localDatabase, "Local Database"), (.remoteAPI, "Remote API"),
            (.localNotifications, "Local Notifications")
        ]
    }

    private func title(for route: ServicesRoute) -> String {
        services.first { $0.route == route }?.title ?? "Services"
    }

    private var isMacOS: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }
}
