import Testing
@testable import AppTemplate

@MainActor
struct NavigationGuideViewModelTests {
    @Test
    func guideExposesPresentationItems() {
        let guide = NavigationGuideViewModel()

        #expect(guide.items.map(\.title) == [
            "Typed paths",
            "Independent tabs",
            "Scene restoration"
        ])
    }

    @Test
    func navigationGuideScreenCanBeConstructed() {
        _ = NavigationGuideView()
    }
}
