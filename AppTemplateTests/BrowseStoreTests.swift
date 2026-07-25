import Foundation
import Testing
@testable import AppTemplate

@MainActor
struct BrowseStoreTests {
    @Test
    func listLoadsRepositoryItems() async {
        let item = BrowseItem(id: "one", title: "One", summary: "First")
        let store = BrowseListStore(
            repository: InMemoryBrowseRepository(items: [item])
        )

        await store.load()

        #expect(store.state == .content([item]))
    }

    @Test
    func detailLoadsByStableIdentifier() async {
        let item = BrowseItem(id: "one", title: "One", summary: "First")
        let store = BrowseDetailStore(
            id: item.id,
            repository: InMemoryBrowseRepository(items: [item])
        )

        await store.load()

        #expect(store.state == .content(item))
    }

    @Test
    func missingDetailProducesNotFound() async {
        let store = BrowseDetailStore(
            id: "missing",
            repository: InMemoryBrowseRepository(items: [])
        )

        await store.load()

        #expect(store.state == .notFound)
    }

    @Test
    func repositoryFailureProducesDisplaySafeFailure() async {
        let store = BrowseDetailStore(
            id: "one",
            repository: FailingBrowseRepository()
        )

        await store.load()

        #expect(store.state == .failed(.load))
    }

    @Test
    func staleDetailResponseCannotReplaceNewerResult() async throws {
        let old = BrowseItem(id: "one", title: "Old", summary: "Slow")
        let new = BrowseItem(id: "one", title: "New", summary: "Fast")
        let repository = SequencedBrowseRepository(responses: [
            (.milliseconds(80), old),
            (.zero, new)
        ])
        let store = BrowseDetailStore(id: "one", repository: repository)

        let first = Task { await store.load() }
        try await ContinuousClock().sleep(for: .milliseconds(10))
        await store.load()
        await first.value

        #expect(store.state == .content(new))
    }

    @Test
    func cancelledDetailLoadDoesNotBecomeFailure() async throws {
        let item = BrowseItem(id: "one", title: "One", summary: "Slow")
        let repository = SequencedBrowseRepository(responses: [
            (.seconds(1), item)
        ])
        let store = BrowseDetailStore(id: "one", repository: repository)

        let load = Task { await store.load() }
        try await ContinuousClock().sleep(for: .milliseconds(10))
        load.cancel()
        await load.value

        #expect(store.state == .idle)
    }
}

private nonisolated enum BrowseRepositoryTestError: Error {
    case failed
}

private actor FailingBrowseRepository: BrowseRepository {
    func items() throws -> [BrowseItem] {
        throw BrowseRepositoryTestError.failed
    }

    func item(id: BrowseItem.ID) throws -> BrowseItem? {
        throw BrowseRepositoryTestError.failed
    }
}

private actor SequencedBrowseRepository: BrowseRepository {
    private var responses: [(Duration, BrowseItem?)]

    init(responses: [(Duration, BrowseItem?)]) {
        self.responses = responses
    }

    func items() -> [BrowseItem] {
        []
    }

    func item(id: BrowseItem.ID) async throws -> BrowseItem? {
        let response = responses.removeFirst()
        try await ContinuousClock().sleep(for: response.0)
        return response.1
    }
}
