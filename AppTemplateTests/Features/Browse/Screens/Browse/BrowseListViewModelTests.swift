import Foundation
import Testing
@testable import AppTemplate

@MainActor
struct BrowseListViewModelTests {
    @Test
    func listLoadsServiceItems() async {
        let item = BrowseItem(id: "one", title: "One", summary: "First")
        let viewModel = BrowseListViewModel(
            dependencies: BrowseDependencies(
                service: BrowseService(items: [item])
            )
        )

        await viewModel.load()

        #expect(viewModel.state == .content([item]))
    }

    @Test
    func listFailureProducesDisplaySafeFailure() async {
        let viewModel = BrowseListViewModel(
            dependencies: BrowseDependencies(
                service: FailingBrowseService()
            )
        )

        await viewModel.load()

        #expect(viewModel.state == .failed(.load))
    }

    @Test
    func cancelledListLoadDoesNotPublishNonCooperativeResponse() async {
        let item = BrowseItem(id: "one", title: "One", summary: "Late")
        let service = ControlledBrowseService()
        let viewModel = BrowseListViewModel(
            dependencies: BrowseDependencies(service: service)
        )

        let load = Task { await viewModel.load() }
        await service.waitForCalls(lists: 1)
        load.cancel()
        await service.resumeItems(at: 0, returning: [item])
        await load.value

        #expect(viewModel.state == .idle)
    }

    @Test
    func cancelledListLoadTreatsOrdinaryServiceErrorAsCancellation() async {
        let service = ControlledBrowseService()
        let viewModel = BrowseListViewModel(
            dependencies: BrowseDependencies(service: service)
        )

        let load = Task { await viewModel.load() }
        await service.waitForCalls(lists: 1)
        load.cancel()
        await service.failItems(at: 0)
        await load.value
        let loadWasCancelled = await service.listWasCancelled(at: 0)

        #expect(loadWasCancelled)
        #expect(viewModel.state == .idle)
    }

    @Test
    func replacementListLoadCancelsAndRejectsStaleResponse() async {
        let old = BrowseItem(id: "old", title: "Old", summary: "Slow")
        let new = BrowseItem(id: "new", title: "New", summary: "Current")
        let service = ControlledBrowseService()
        let viewModel = BrowseListViewModel(
            dependencies: BrowseDependencies(service: service)
        )

        let first = Task { await viewModel.load() }
        await service.waitForCalls(lists: 1)

        let second = Task { await viewModel.load() }
        await service.waitForCalls(lists: 2)
        await service.resumeItems(at: 1, returning: [new])
        await second.value
        await service.resumeItems(at: 0, returning: [old])
        await first.value
        let firstWasCancelled = await service.listWasCancelled(at: 0)

        #expect(firstWasCancelled)
        #expect(viewModel.state == .content([new]))
    }

    @Test
    func browseListScreenUsesScopedDependencies() {
        let dependencies = BrowseDependencies(
            service: BrowseService(items: [])
        )

        _ = BrowseNavigationView(
            router: BrowseRouter(),
            dependencies: dependencies
        )
    }
}
