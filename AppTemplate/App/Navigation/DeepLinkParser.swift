import Foundation

struct DeepLinkParser: Sendable {
    func parse(_ url: URL) -> Result<NavigationIntent, DeepLinkError> {
        guard url.scheme?.lowercased() == "apptemplate" else {
            return .failure(.unsupportedScheme)
        }

        guard let host = url.host?.lowercased() else {
            return .failure(.unknownDestination)
        }
        let segments = url.pathComponents.filter { $0 != "/" }

        switch host {
        case "home" where segments.isEmpty:
            return .success(.selectSection(.home))
        case "browse" where segments.isEmpty:
            return .success(.selectSection(.browse))
        case "settings" where segments.isEmpty:
            return .success(.selectSection(.settings))
        case "browse" where segments.count == 2 && segments[0] == "item":
            let encodedID = segments[1]
            guard let id = encodedID.removingPercentEncoding, !id.isEmpty else {
                return .failure(.unknownDestination)
            }
            return .success(.browseItem(id: id))
        default:
            return .failure(.unknownDestination)
        }
    }
}
