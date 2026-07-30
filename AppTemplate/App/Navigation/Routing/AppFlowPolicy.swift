nonisolated
enum AppFlowPolicy {
    static func resolve(_ state: AppState) -> AppFlow {
        if !state.hasCompletedOnboarding {
            return .onboarding
        }
        if !state.isAuthenticated {
            return .authentication
        }
        if state.isMaintenanceEnabled {
            return .maintenance
        }
        return .main
    }
}
