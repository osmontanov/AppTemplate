import Foundation

extension AppSection {
    var localizedTitle: LocalizedStringResource {
        switch self {
        case .store: StoreServicesText.resource(.storeTitle)
        case .services: StoreServicesText.resource(.servicesTitle)
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
