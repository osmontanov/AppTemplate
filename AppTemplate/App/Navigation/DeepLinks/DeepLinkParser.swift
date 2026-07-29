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
        let encodedPath = url.path(percentEncoded: true)
        let encodedSegments: [Substring]
        if encodedPath.isEmpty {
            encodedSegments = []
        } else {
            guard encodedPath.first == "/" else {
                return .failure(.unknownDestination)
            }
            encodedSegments = encodedPath
                .dropFirst()
                .split(separator: "/", omittingEmptySubsequences: false)
            guard encodedSegments.allSatisfy({ !$0.isEmpty }) else {
                return .failure(.unknownDestination)
            }
        }

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
        case "projects" where segments.isEmpty:
            return .success(.selectSection(.projects))
        case "settings" where segments.isEmpty:
            return .success(.selectSection(.settings))
        case "browse" where segments.count == 2 && segments[0] == "item":
            let id = segments[1]
            guard !id.isEmpty else {
                return .failure(.unknownDestination)
            }
            return .success(.browseItem(id: id))
        case "projects" where segments.count == 2 && segments[0] == "project":
            let id = segments[1]
            guard !id.isEmpty else {
                return .failure(.unknownDestination)
            }
            return .success(.project(id: id))
        case "projects"
            where segments.count == 4
                && segments[0] == "project"
                && segments[2] == "task":
            let projectID = segments[1]
            let taskID = segments[3]
            guard !projectID.isEmpty, !taskID.isEmpty else {
                return .failure(.unknownDestination)
            }
            return .success(
                .projectTask(projectID: projectID, taskID: taskID)
            )
        default:
            return .failure(.unknownDestination)
        }
    }
}
