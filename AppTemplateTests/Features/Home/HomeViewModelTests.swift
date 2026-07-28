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
    func staticHomeScreensExposePresentationModels() {
        let details = HomeDetailsViewModel()
        let guide = NavigationGuideViewModel()

        #expect(details.title == "Typed Destination")
        #expect(details.message == "HomeRoute.details produced this screen.")
        #expect(guide.items.map(\.title) == [
            "Typed paths",
            "Independent tabs",
            "Scene restoration"
        ])
    }

    @Test
    func everyHomeScreenCanBeConstructed() {
        _ = HomeNavigationView(router: HomeRouter())
        _ = HomeDetailsView()
        _ = NavigationGuideView()
    }
}
