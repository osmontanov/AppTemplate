import Foundation

struct DeepLinkParser: Sendable {
    func fallbackSection(for url: URL) -> AppSection {
        guard url.scheme?.lowercased() == "apptemplate",
              let host = url.host?.lowercased(),
              let section = AppSection(rawValue: host) else {
            return .home
        }
        return section
    }

    func parse(_ url: URL) -> Result<NavigationIntent, DeepLinkError> {
        guard url.scheme?.lowercased() == "apptemplate" else {
            return .failure(.unsupportedScheme)
        }

        guard let host = url.host?.lowercased() else {
            return .failure(.unknownDestination)
        }
        let encodedSegments = url.path(percentEncoded: true).split(separator: "/")
        var segments: [String] = []
        segments.reserveCapacity(encodedSegments.count)
        for encodedSegment in encodedSegments {
            guard let segment = String(encodedSegment).removingPercentEncoding else {
                return .failure(.unknownDestination)
            }
            segments.append(segment)
        }

        switch host {
        case "home" where segments.isEmpty:
            return .success(.selectSection(.home))
        case "browse" where segments.isEmpty:
            return .success(.selectSection(.browse))
        case "settings" where segments.isEmpty:
            return .success(.selectSection(.settings))
        case "browse" where segments.count == 2 && segments[0] == "item":
            let id = segments[1]
            guard !id.isEmpty else {
                return .failure(.unknownDestination)
            }
            return .success(.browseItem(id: id))
        default:
            return .failure(.unknownDestination)
        }
    }
}
