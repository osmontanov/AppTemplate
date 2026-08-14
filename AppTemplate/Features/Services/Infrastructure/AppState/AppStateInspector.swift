import Observation

@MainActor
@Observable
final class AppStateInspector: IAppStateInspecting {
    private let store: AppStateStore
    private let router: AppFlowRouter

    init(store: AppStateStore, router: AppFlowRouter) {
        self.store = store
        self.router = router
    }

    var inspection: AppStateInspection {
        AppStateInspection(
            schemaVersion: store.state.schemaVersion,
            hasCompletedOnboarding: store.state.hasCompletedOnboarding,
            isMaintenanceEnabled: store.state.isMaintenanceEnabled,
            persistenceStatus: store.persistenceStatus,
            root: router.flow
        )
    }
}
