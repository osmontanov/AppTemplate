nonisolated
struct AppStateInspection: Equatable, Sendable {
    let schemaVersion: Int
    let hasCompletedOnboarding: Bool
    let isMaintenanceEnabled: Bool
    let persistenceStatus: AppStatePersistenceStatus
    let root: AppFlow
}

@MainActor
protocol IAppStateInspecting: AnyObject {
    var inspection: AppStateInspection { get }
}
