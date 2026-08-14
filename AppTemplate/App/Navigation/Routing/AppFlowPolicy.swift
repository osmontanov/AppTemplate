nonisolated
enum AppFlowPolicy {
    static func resolve(
        _ state: AppState,
        isLocalSessionBootstrapResolved: Bool
    ) -> AppFlow {
        if state.isMaintenanceEnabled {
            return .maintenance
        }
        if !state.hasCompletedOnboarding {
            return .onboarding
        }
        if !isLocalSessionBootstrapResolved {
            return .restoring
        }
        return .main
    }
}
