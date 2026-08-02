import Foundation

nonisolated
struct AppState: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1
    static let initial = AppState(
        isAuthenticated: false,
        hasCompletedOnboarding: false,
        isMaintenanceEnabled: false
    )

    let schemaVersion: Int
    var isAuthenticated: Bool
    var hasCompletedOnboarding: Bool
    var isMaintenanceEnabled: Bool

    init(
        schemaVersion: Int = currentSchemaVersion,
        isAuthenticated: Bool,
        hasCompletedOnboarding: Bool,
        isMaintenanceEnabled: Bool
    ) {
        self.schemaVersion = schemaVersion
        self.isAuthenticated = isAuthenticated
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.isMaintenanceEnabled = isMaintenanceEnabled
    }
}
