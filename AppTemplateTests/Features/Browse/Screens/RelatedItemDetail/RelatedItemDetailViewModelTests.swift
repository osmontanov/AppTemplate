import Testing
@testable import AppTemplate

@MainActor
struct RelatedItemDetailViewModelTests {
    @Test
    func relatedItemDetailStateScaffoldCanBeConstructed() {
        _ = RelatedItemDetailScreenState()
    }

    @Test
    func relatedItemDetailRetainsItsStableIdentifier() {
        let viewModel = RelatedItemDetailViewModel(id: "observation")

        #expect(viewModel.id == "observation")
    }

    @Test
    func relatedItemDetailScreenUsesNavigationOnlyInitializer() {
        _ = RelatedItemDetailView(id: "observation")
    }
}
