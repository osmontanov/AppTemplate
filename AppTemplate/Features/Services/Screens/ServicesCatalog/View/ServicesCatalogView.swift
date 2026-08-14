import SwiftUI

struct ServicesCatalogView: View {
    let items: [ServicesCatalogItem]

    init(items: [ServicesCatalogItem] = ServicesCatalogViewModel.items) {
        self.items = items
    }

    var body: some View {
        List(items) { item in
            NavigationLink(value: item.route) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.route.displayTitle)
                    Text(item.guide.why)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .accessibilityIdentifier("route.services.\(item.route.accessibilityWireValue)")
        }
        .navigationTitle("Services")
        .accessibilityIdentifier("screen.services.root")
    }
}

nonisolated
extension ServicesRoute {
    var accessibilityWireValue: String {
        switch self {
        case .appState: "app-state"
        case .appInfo: "app-info"
        case .userDefaults: "user-defaults"
        case .keychain: "keychain"
        case .localDatabase: "local-database"
        case .remoteAPI: "remote-api"
        case .localNotifications: "local-notifications"
        }
    }

    var displayTitle: String {
        switch self {
        case .appState: "App State"
        case .appInfo: "App Info"
        case .userDefaults: "UserDefaults"
        case .keychain: "Keychain"
        case .localDatabase: "Local Database"
        case .remoteAPI: "Remote API"
        case .localNotifications: "Local Notifications"
        }
    }
}
