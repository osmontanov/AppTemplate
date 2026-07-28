import Testing
@testable import AppTemplate

@MainActor
struct HomeDetailsViewModelTests {
    @Test
    func detailsExposePresentationModel() {
        let details = HomeDetailsViewModel()

        #expect(details.title == "Typed Destination")
        #expect(details.message == "HomeRoute.details produced this screen.")
    }

    @Test
    func homeDetailsScreenCanBeConstructed() {
        _ = HomeDetailsView()
    }
}
