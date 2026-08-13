import Foundation

nonisolated
struct AppState: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 2
    static let initial = AppState(
        hasCompletedOnboarding: false,
        isMaintenanceEnabled: false
    )

    let schemaVersion: Int
    var hasCompletedOnboarding: Bool
    var isMaintenanceEnabled: Bool

    init(
        schemaVersion: Int = currentSchemaVersion,
        hasCompletedOnboarding: Bool,
        isMaintenanceEnabled: Bool
    ) {
        self.schemaVersion = schemaVersion
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.isMaintenanceEnabled = isMaintenanceEnabled
    }
}
