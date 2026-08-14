import Foundation

nonisolated
enum AppFlow: String, Codable, Equatable, Sendable {
    case restoring
    case onboarding
    case maintenance
    case main
}

enum NavigationOutcome: Equatable, Sendable {
    case applied
    case deferred
}
