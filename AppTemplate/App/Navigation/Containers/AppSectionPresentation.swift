import Foundation

extension AppSection {
    var localizedTitle: LocalizedStringResource {
        switch self {
        case .store: AppText.resource("Store")
        case .services: AppText.resource("Services")
        }
    }

    var systemImage: String {
        switch self {
        case .store: "storefront"
        case .services: "wrench.and.screwdriver"
        }
    }

    var presentationIdentifier: String { "app.section.\(rawValue)" }
    var accessibilityIdentifier: String { "tab.\(rawValue)" }
}
