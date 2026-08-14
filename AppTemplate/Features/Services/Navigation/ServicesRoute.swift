import Foundation

nonisolated
enum ServicesRoute: NavigationRoute {
    case appState
    case appInfo
    case userDefaults
    case keychain
    case localDatabase
    case remoteAPI
    case localNotifications

    private enum CodingKeys: String, CodingKey { case tag }
    private enum Tag: String, Codable {
        case appState = "app-state"
        case appInfo = "app-info"
        case userDefaults = "user-defaults"
        case keychain
        case localDatabase = "local-database"
        case remoteAPI = "remote-api"
        case localNotifications = "local-notifications"
    }

    init(from decoder: Decoder) throws {
        let dynamic = try decoder.container(keyedBy: DynamicCodingKey.self)
        try dynamic.rejectUnknownKeys(allowed: ["tag"])
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Tag.self, forKey: .tag) {
        case .appState: self = .appState
        case .appInfo: self = .appInfo
        case .userDefaults: self = .userDefaults
        case .keychain: self = .keychain
        case .localDatabase: self = .localDatabase
        case .remoteAPI: self = .remoteAPI
        case .localNotifications: self = .localNotifications
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let tag: Tag = switch self {
        case .appState: .appState
        case .appInfo: .appInfo
        case .userDefaults: .userDefaults
        case .keychain: .keychain
        case .localDatabase: .localDatabase
        case .remoteAPI: .remoteAPI
        case .localNotifications: .localNotifications
        }
        try container.encode(tag, forKey: .tag)
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
        case .appState: StoreServicesText.string("App State")
        case .appInfo: StoreServicesText.string("App Info")
        case .userDefaults: StoreServicesText.string("UserDefaults")
        case .keychain: StoreServicesText.string("Keychain")
        case .localDatabase: StoreServicesText.string("Local Database")
        case .remoteAPI: StoreServicesText.string("Remote API")
        case .localNotifications: StoreServicesText.string("Local Notifications")
        }
    }
}
