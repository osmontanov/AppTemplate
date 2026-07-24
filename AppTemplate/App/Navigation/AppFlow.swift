import Foundation

enum AppFlow: String, Codable, Equatable, Sendable {
    case launching
    case authentication
    case main
}

enum NavigationRejection: Equatable, Sendable {
    case missingBrowseItem(BrowseItem.ID)
}

enum NavigationOutcome: Equatable, Sendable {
    case applied
    case deferred
    case rejected(NavigationRejection)
}
