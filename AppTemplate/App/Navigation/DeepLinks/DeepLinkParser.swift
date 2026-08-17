import Foundation

nonisolated
struct DeepLinkParser: Sendable {
    private let scheme: String

    init(scheme: String = AppURLScheme.scheme) {
        self.scheme = scheme.lowercased()
    }

    func parse(_ url: URL) -> Result<NavigationIntent, DeepLinkError> {
        guard let components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        ), components.scheme?.lowercased() == scheme else {
            return .failure(.invalidScheme)
        }
        guard components.user == nil, components.password == nil else {
            return .failure(.credentialsNotAllowed)
        }
        guard components.port == nil else {
            return .failure(.portNotAllowed)
        }
        guard components.percentEncodedQuery == nil else {
            return .failure(.queryNotAllowed)
        }
        guard components.percentEncodedFragment == nil else {
            return .failure(.fragmentNotAllowed)
        }

        let host = components.host?.lowercased()
        guard host == AppSection.store.rawValue
                || host == AppSection.services.rawValue else {
            return .failure(.unsupportedHost)
        }

        let percentEncodedPath = components.percentEncodedPath
        if percentEncodedPath.isEmpty {
            return host == AppSection.store.rawValue
                ? .success(.openStoreRoot)
                : .success(.openServicesRoot)
        }
        guard percentEncodedPath.first == "/",
              percentEncodedPath.last != "/" else {
            return .failure(.invalidSegments)
        }
        let encodedSegments = percentEncodedPath
            .dropFirst()
            .split(separator: "/", omittingEmptySubsequences: false)
        guard !encodedSegments.isEmpty,
              !encodedSegments.contains(where: { $0.isEmpty }) else {
            return .failure(.invalidSegments)
        }
        let segments = encodedSegments.compactMap {
            String($0).removingPercentEncoding
        }
        guard segments.count == encodedSegments.count else {
            return .failure(.invalidSegments)
        }

        if host == AppSection.store.rawValue {
            return parseStore(segments)
        }
        return parseServices(segments)
    }

    private func parseStore(
        _ segments: [String]
    ) -> Result<NavigationIntent, DeepLinkError> {
        if segments == ["favorites"] {
            return .success(.openFavorites)
        }
        if segments == ["profile"] {
            return .success(.openProfile)
        }
        if segments.count == 2, segments[0] == "product" {
            let rawID = segments[1]
            guard !rawID.isEmpty,
                  rawID.utf8.allSatisfy({ (48...57).contains($0) }),
                  let id = Int(rawID),
                  id > 0 else {
                return .failure(.invalidProductID)
            }
            return .success(.openProduct(id))
        }
        return .failure(.invalidSegments)
    }

    private func parseServices(
        _ segments: [String]
    ) -> Result<NavigationIntent, DeepLinkError> {
        guard segments.count == 1 else {
            return .failure(.invalidSegments)
        }
        let route: ServicesRoute
        switch segments[0] {
        case "app-state": route = .appState
        case "app-info": route = .appInfo
        case "user-defaults": route = .userDefaults
        case "keychain": route = .keychain
        case "local-database": route = .localDatabase
        case "remote-api": route = .remoteAPI
        case "local-notifications": route = .localNotifications
        default: return .failure(.invalidSegments)
        }
        return .success(.openService(route))
    }
}
