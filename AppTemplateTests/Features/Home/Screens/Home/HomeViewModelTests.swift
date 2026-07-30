import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct HomeViewModelTests {
    @Test
    func userIntentsPushScreenOwnedRoutes() {
        let router = FlowRouter()
        let viewModel = HomeViewModel(router: router)

        viewModel.openDetails()
        viewModel.openNavigationGuide()

        #expect(router.path.count == 2)
        #expect(router.path.codable != nil)
    }

    @Test
    func resetAlertIsLocalAndConfirmationClearsTheFlow() {
        let router = FlowRouter()
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
        let router = FlowRouter()
        let viewModel = HomeViewModel(router: router)
        viewModel.requestNavigationReset()

        viewModel.isResetAlertPresented = false

        #expect(viewModel.alert == nil)
    }

    @Test
    func homeOwnsQuickStartSheetState() {
        let viewModel = HomeViewModel(router: FlowRouter())

        viewModel.openQuickStart()
        #expect(viewModel.sheet == .quickStart)

        viewModel.dismissSheet()
        #expect(viewModel.sheet == nil)
    }

    @Test
    func openingOnboardingChangesTheAppFlow() {
        let appFlowRouter = AppFlowRouter(flow: .main)
        let router = FlowRouter(appFlowRouter: appFlowRouter)
        let viewModel = HomeViewModel(router: router)

        viewModel.openOnboarding()

        #expect(appFlowRouter.flow == .onboarding)
    }

    @Test
    func openingMaintenanceChangesTheAppFlow() {
        let appFlowRouter = AppFlowRouter(flow: .main)
        let router = FlowRouter(appFlowRouter: appFlowRouter)
        let viewModel = HomeViewModel(router: router)

        viewModel.openMaintenance()

        #expect(appFlowRouter.flow == .maintenance)
    }

    @Test
    func homeFlowAndScreenCanBeConstructed() {
        let router = FlowRouter()

        _ = HomeFlowView(router: router)
        _ = HomeView(router: router)
    }
}
