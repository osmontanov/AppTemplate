import Testing
@testable import AppTemplate

struct LoadableStateTests {
    @Test
    func representsTheCompleteLoadingLifecycle() {
        let item = BrowseItem(
            id: "one",
            title: "One",
            summary: "First"
        )
        typealias State = LoadableState<[BrowseItem], BrowseFailure>

        #expect(State.idle == .idle)
        #expect(State.loading == .loading)
        #expect(State.content([item]) == .content([item]))
        #expect(State.empty == .empty)
        #expect(State.failed(.load) == .failed(.load))
    }
}
