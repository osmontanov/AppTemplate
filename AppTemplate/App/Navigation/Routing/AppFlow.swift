import Foundation

nonisolated
enum AppFlow: String, Codable, Equatable, Sendable {
    case launching
    case authentication
    case onboarding
    case main
    case maintenance
}

enum NavigationOutcome: Equatable, Sendable {
    case applied
    case deferred
}
