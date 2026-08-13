nonisolated
enum AppFlowPolicy {
    @MainActor
    static func resolve(
        _ state: AppState,
        legacyAuthentication: LegacyAuthenticationState
    ) -> AppFlow {
        if !state.hasCompletedOnboarding {
            return .onboarding
        }
        if !legacyAuthentication.isAuthenticated {
            return .authentication
        }
        if state.isMaintenanceEnabled {
            return .maintenance
        }
        return .main
    }
}
