import Foundation

nonisolated
struct DeepLinkParser: Sendable {
    private let scheme: String

    init(scheme: String = "apptemplate") {
        self.scheme = scheme.lowercased()
    }

    func fallbackSection(for url: URL) -> AppSection {
        guard url.scheme?.lowercased() == scheme,
              url.host?.lowercased() == AppSection.services.rawValue else {
            return .store
        }
        return .services
    }

    func parse(_ url: URL) -> Result<NavigationIntent, DeepLinkError> {
        guard url.scheme?.lowercased() == scheme else {
            return .failure(.unsupportedScheme)
        }
        guard url.path(percentEncoded: true).isEmpty else {
            return .failure(.unknownDestination)
        }
        switch url.host?.lowercased() {
        case AppSection.store.rawValue:
            return .success(.openStoreRoot)
        case AppSection.services.rawValue:
            return .success(.openServicesRoot)
        default:
            return .failure(.unknownDestination)
        }
    }
}
