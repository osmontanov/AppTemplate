import Testing
@testable import AppTemplate

struct AppFlowCoordinatorTests {
    @Test @MainActor func localBootstrapResolutionReleasesRestoringToMain() {
        let coordinator = makeTestAppFlowCoordinator(
            state: .init(hasCompletedOnboarding: true, isMaintenanceEnabled: false),
            isLocalSessionBootstrapResolved: false
        )

        coordinator.setLocalSessionBootstrapResolved(true)

        #expect(coordinator.appFlowRouter.flow == .main)
        #expect(coordinator.appFlowRouter.transition.historyAction == .preserve)
    }

    @Test @MainActor func maintenanceWinsWhileBootstrapIsUnresolved() {
        let coordinator = makeTestAppFlowCoordinator(
            state: .init(hasCompletedOnboarding: true, isMaintenanceEnabled: false),
            isLocalSessionBootstrapResolved: false
        )

        #expect(coordinator.setMaintenanceEnabled(true) == .applied(
            flow: .maintenance,
            didTransition: true
        ))
        #expect(coordinator.appFlowRouter.transition.historyAction == .preserve)
    }

    @Test @MainActor func onboardingAndMaintenancePersistenceRejectionsAreRetained() {
        let storage = AppStateStorageSpy(saveError: CoordinatorWriteFailure())
        let store = AppStateStore(storage: storage)
        let router = AppFlowRouter(flow: .onboarding)
        let coordinator = AppFlowCoordinator(
            store: store,
            appFlowRouter: router,
            isLocalSessionBootstrapResolved: true
        )

        #expect(coordinator.completeOnboarding() == .rejected(.saveFailed))
        #expect(router.flow == .onboarding)
    }
}

private struct CoordinatorWriteFailure: Error {}
