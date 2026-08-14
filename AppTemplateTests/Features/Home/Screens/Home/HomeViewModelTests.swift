import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct HomeViewModelTests {
    @Test
    func userIntentsPushScreenOwnedRoutes() {
        let router = makeTestFlowRouter()
        let viewModel = makeHomeViewModel(router: router)

        viewModel.openDetails()
        viewModel.openNavigationGuide()

        #expect(router.path.count == 2)
        #expect(router.path.codable != nil)
    }

    @Test
    func resetAlertIsLocalAndConfirmationClearsTheFlow() {
        let router = makeTestFlowRouter()
        router.push(HomeRoute.details)
        let viewModel = makeHomeViewModel(router: router)

        viewModel.requestNavigationReset()
        #expect(viewModel.alert == .resetNavigation)
        #expect(viewModel.isResetAlertPresented)

        viewModel.confirmNavigationReset()

        #expect(router.path.isEmpty)
        #expect(viewModel.alert == nil)
    }

    @Test
    func dismissingResetBindingClearsTheAlert() {
        let router = makeTestFlowRouter()
        let viewModel = makeHomeViewModel(router: router)
        viewModel.requestNavigationReset()

        viewModel.isResetAlertPresented = false

        #expect(viewModel.alert == nil)
    }

    @Test
    func homeOwnsQuickStartSheetState() {
        let viewModel = makeHomeViewModel()

        viewModel.openQuickStart()
        #expect(viewModel.sheet == .quickStart)

        viewModel.dismissSheet()
        #expect(viewModel.sheet == nil)
    }

    @Test
    func homeRootActionsApplyPersistentPolicyChanges() {
        let mainState = AppState(
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: false
        )
        let onboardingCoordinator = makeTestAppFlowCoordinator(
            state: mainState,
            isLocalSessionBootstrapResolved: true
        )
        let maintenanceCoordinator = makeTestAppFlowCoordinator(
            state: mainState,
            isLocalSessionBootstrapResolved: true
        )
        let viewModel = HomeViewModel(
            router: makeTestFlowRouter(),
            onboardingActions: onboardingCoordinator,
            maintenanceActions: maintenanceCoordinator
        )

        viewModel.openOnboarding()
        viewModel.openMaintenance()

        #expect(onboardingCoordinator.appFlowRouter.flow == .onboarding)
        #expect(maintenanceCoordinator.appFlowRouter.flow == .maintenance)
    }

    @Test
    func homeFlowAndScreenCanBeConstructed() {
        let router = makeTestFlowRouter()

        _ = HomeFlowView(router: router)
        _ = HomeView(router: router)
    }

    private func makeHomeViewModel(
        router: FlowRouter? = nil
    ) -> HomeViewModel {
        let router = router ?? makeTestFlowRouter()
        return HomeViewModel(
            router: router,
            onboardingActions: router,
            maintenanceActions: router
        )
    }
}
