import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct HomeViewModelTests {
    @Test
    func userIntentsPushScreenOwnedRoutes() {
        let router = makeTestFlowRouter()
        let viewModel = HomeViewModel(router: router)

        viewModel.openDetails()
        viewModel.openNavigationGuide()

        #expect(router.path.count == 2)
        #expect(router.path.codable != nil)
    }

    @Test
    func resetAlertIsLocalAndConfirmationClearsTheFlow() {
        let router = makeTestFlowRouter()
        router.push(HomeRoute.details)
        let viewModel = HomeViewModel(router: router)

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
        let viewModel = HomeViewModel(router: router)
        viewModel.requestNavigationReset()

        viewModel.isResetAlertPresented = false

        #expect(viewModel.alert == nil)
    }

    @Test
    func homeOwnsQuickStartSheetState() {
        let viewModel = HomeViewModel(router: makeTestFlowRouter())

        viewModel.openQuickStart()
        #expect(viewModel.sheet == .quickStart)

        viewModel.dismissSheet()
        #expect(viewModel.sheet == nil)
    }

    @Test
    func homeRootActionsRequestPersistentPolicyChanges() {
        let coordinator = AppFlowCoordinatorSpy()
        let viewModel = HomeViewModel(
            router: FlowRouter(appFlowCoordinator: coordinator)
        )

        viewModel.openOnboarding()
        viewModel.openMaintenance()

        #expect(coordinator.commands == [
            .restartOnboarding,
            .setMaintenanceEnabled(true)
        ])
    }

    @Test
    func homeFlowAndScreenCanBeConstructed() {
        let router = makeTestFlowRouter()

        _ = HomeFlowView(router: router)
        _ = HomeView(router: router)
    }
}
