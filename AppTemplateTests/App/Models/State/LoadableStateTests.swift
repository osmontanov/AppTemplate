import Testing
@testable import AppTemplate

struct LoadableStateTests {
    @Test
    func representsTheCompleteLoadingLifecycle() {
        typealias State = LoadableState<[String], LoadableStateTestFailure>

        #expect(State.idle == .idle)
        #expect(State.loading == .loading)
        #expect(State.content(["one"]) == .content(["one"]))
        #expect(State.empty == .empty)
        #expect(State.failed(.load) == .failed(.load))
    }
}

nonisolated
private enum LoadableStateTestFailure:
    Equatable,
    Sendable {
    case load
}
