import Testing
@testable import AppTemplate

@MainActor
struct GuideTopicViewModelTests {
    @Test
    func topicResolvesItsStableGuideItemID() {
        let viewModel = GuideTopicViewModel(id: "independent-flows")

        #expect(viewModel.item?.title == "Independent flows")
    }

    @Test
    func unknownTopicUsesAnEmptyState() {
        let viewModel = GuideTopicViewModel(id: "missing")

        #expect(viewModel.item == nil)
    }
}
