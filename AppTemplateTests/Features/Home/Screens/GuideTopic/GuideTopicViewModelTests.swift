import Testing
import SwiftUI
@testable import AppTemplate

@MainActor
struct GuideTopicViewModelTests {
    @Test
    func topicRetainsItsSuppliedStableID() {
        let viewModel = GuideTopicViewModel(id: "independent-flows")

        #expect(viewModel.id == "independent-flows")
    }

    @Test
    func guideTopicScreenCanBeConstructed() {
        _ = GuideTopicView(id: "independent-flows")
    }
}
