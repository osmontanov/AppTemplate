import Foundation

nonisolated struct UITestScenario: Equatable, Sendable {
    nonisolated enum Name: String, CaseIterable, Codable, Sendable {
        case guestStore = "guest-store"
        case protectedFavorite = "protected-favorite"
        case productReminder = "product-reminder"
        case servicesBasic = "services-basic"
        case accessibilitySmoke = "accessibility-smoke"
    }

    let id: Name
    let appState: AppState
    let sessionSeed: UITestSessionSeed
    let localDatabaseSeed: UITestLocalDatabaseSeed
    let preferencesSeed: UITestPreferencesSeed
    let notificationSeed: UITestNotificationSeed
    let imageSeed: UITestImageSeed
    let remoteSteps: [ScriptedNetworkStep]

    static func named(_ id: String) throws -> UITestScenario {
        guard let name = Name(rawValue: id) else {
            throw UITestConfigurationError.unknownScenario(id)
        }
        let state: AppState
        switch name {
        case .accessibilitySmoke:
            state = .initial
        case .guestStore, .protectedFavorite, .productReminder, .servicesBasic:
            state = AppState(
                hasCompletedOnboarding: true,
                isMaintenanceEnabled: false
            )
        }
        return UITestScenario(
            id: name,
            appState: state,
            sessionSeed: UITestSessionSeed(keychainData: nil),
            localDatabaseSeed: UITestLocalDatabaseSeed(examples: []),
            preferencesSeed: UITestPreferencesSeed(encodedValues: [:]),
            notificationSeed: UITestNotificationSeed(
                authorizationStatus: .notDetermined,
                pendingRequests: []
            ),
            imageSeed: UITestImageSeed(steps: []),
            remoteSteps: []
        )
    }
}
