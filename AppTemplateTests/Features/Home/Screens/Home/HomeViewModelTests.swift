import Testing
@testable import AppTemplate

@MainActor
struct HomeViewModelTests {
    @Test
    func userIntentsDriveTheHomeRouter() {
        let router = HomeRouter()
        let viewModel = HomeViewModel(router: router)

        viewModel.openDetails()
        #expect(router.path == [.details])

        viewModel.openNavigationGuide()
        #expect(router.sheet == .navigationGuide)

        viewModel.requestNavigationReset()
        #expect(router.alert == .resetNavigation)
        #expect(viewModel.isResetAlertPresented)

        viewModel.cancelNavigationReset()
        #expect(router.alert == nil)
    }

    @Test
    func confirmedResetClearsOnlyHomePresentationState() {
        let router = HomeRouter(
            path: [.details],
            sheet: .navigationGuide,
            alert: .resetNavigation
        )
        let viewModel = HomeViewModel(router: router)

        viewModel.confirmNavigationReset()

        #expect(router.path.isEmpty)
        #expect(router.alert == nil)
        #expect(router.sheet == .navigationGuide)
    }

    @Test
    func dismissingResetBindingClearsTheAlert() {
        let router = HomeRouter(alert: .resetNavigation)
        let viewModel = HomeViewModel(router: router)

        viewModel.isResetAlertPresented = false

        #expect(router.alert == nil)
    }

    @Test
    func homeScreenCanBeConstructed() {
        _ = HomeNavigationView(router: HomeRouter())
    }
}
