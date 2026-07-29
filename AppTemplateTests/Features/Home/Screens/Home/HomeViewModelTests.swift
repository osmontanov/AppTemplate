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
    func homeFlowAndScreenCanBeConstructed() {
        let router = FlowRouter()

        _ = HomeFlowView(router: router)
        _ = HomeView(router: router)
    }
}
