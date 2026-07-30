import Foundation

nonisolated
enum AppFlow: String, Codable, Equatable, Sendable {
    case launching
    case authentication
    case main
}

enum NavigationOutcome: Equatable, Sendable {
    case applied
    case deferred
}
