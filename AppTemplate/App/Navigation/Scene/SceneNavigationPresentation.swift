import Foundation

nonisolated
enum DeepLinkRecoveryAction: Equatable, Sendable {
    case openStore
    case openServices
}

nonisolated
struct DeepLinkFailurePresentation: Equatable, Sendable {
    let reason: DeepLinkError
}

nonisolated
struct SceneNavigationPresentation: Equatable, Sendable {
    let selectedSection: AppSection
    let storePath: [StoreRoute]
    let servicesPath: [ServicesRoute]
    let restorationResult: NavigationRestorationResult
    let checkpoint: UUID?
    let hasDeferredLink: Bool
    let hasPendingProtectedAction: Bool
    let deepLinkFailure: DeepLinkFailurePresentation?
}
