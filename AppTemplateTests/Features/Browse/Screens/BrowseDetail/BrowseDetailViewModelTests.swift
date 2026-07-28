import Foundation
import Testing
@testable import AppTemplate

@MainActor
struct BrowseDetailViewModelTests {
    @Test
    func detailLoadsByStableIdentifier() async {
        let item = BrowseItem(id: "one", title: "One", summary: "First")
        let viewModel = BrowseDetailViewModel(
            id: item.id,
            dependencies: BrowseDependencies(
                service: BrowseService(items: [item])
            )
        )

        await viewModel.load()

        #expect(viewModel.state == .content(item))
    }

    @Test
    func missingDetailProducesNotFound() async {
        let viewModel = BrowseDetailViewModel(
            id: "missing",
            dependencies: BrowseDependencies(
                service: BrowseService(items: [])
            )
        )

        await viewModel.load()

        #expect(viewModel.state == .notFound)
    }

    @Test
    func serviceFailureProducesDisplaySafeFailure() async {
        let viewModel = BrowseDetailViewModel(
            id: "one",
            dependencies: BrowseDependencies(
                service: FailingBrowseService()
            )
        )

        await viewModel.load()

        #expect(viewModel.state == .failed(.load))
    }

    @Test
    func replacementDetailLoadCancelsAndRejectsStaleResponse() async {
        let old = BrowseItem(id: "one", title: "Old", summary: "Slow")
        let new = BrowseItem(id: "one", title: "New", summary: "Fast")
        let service = ControlledBrowseService()
        let viewModel = BrowseDetailViewModel(
            id: "one",
            dependencies: BrowseDependencies(service: service)
        )

        let first = Task { await viewModel.load() }
        await service.waitForCalls(details: 1)

        let second = Task { await viewModel.load() }
        await service.waitForCalls(details: 2)
        await service.resumeItem(at: 1, returning: new)
        await second.value
        await service.resumeItem(at: 0, returning: old)
        await first.value
        let firstWasCancelled = await service.detailWasCancelled(at: 0)

        #expect(firstWasCancelled)
        #expect(viewModel.state == .content(new))
    }

    @Test
    func cancelledDetailLoadDoesNotPublishNonCooperativeResponse() async {
        let item = BrowseItem(id: "one", title: "One", summary: "Late")
        let service = ControlledBrowseService()
        let viewModel = BrowseDetailViewModel(
            id: "one",
            dependencies: BrowseDependencies(service: service)
        )

        let load = Task { await viewModel.load() }
        await service.waitForCalls(details: 1)
        load.cancel()
        await service.resumeItem(at: 0, returning: item)
        await load.value

        #expect(viewModel.state == .idle)
    }

    @Test
    func cancelledDetailLoadTreatsOrdinaryServiceErrorAsCancellation() async {
        let service = ControlledBrowseService()
        let viewModel = BrowseDetailViewModel(
            id: "one",
            dependencies: BrowseDependencies(service: service)
        )

        let load = Task { await viewModel.load() }
        await service.waitForCalls(details: 1)
        load.cancel()
        await service.failItem(at: 0)
        await load.value
        let loadWasCancelled = await service.detailWasCancelled(at: 0)

        #expect(loadWasCancelled)
        #expect(viewModel.state == .idle)
    }

    @Test
    func retryThenDestinationCancellationCancelsOwnedLoad() async {
        let item = BrowseItem(id: "one", title: "One", summary: "Late")
        let service = ControlledBrowseService()
        let viewModel = BrowseDetailViewModel(
            id: "one",
            dependencies: BrowseDependencies(service: service)
        )

        let initialLoad = Task { await viewModel.load() }
        await service.waitForCalls(details: 1)
        await service.failItem(at: 0)
        await initialLoad.value
        #expect(viewModel.state == .failed(.load))

        let retry = viewModel.retry()
        await service.waitForCalls(details: 2)
        viewModel.cancel()
        await service.resumeItem(at: 1, returning: item)
        await retry.value
        let retryWasCancelled = await service.detailWasCancelled(at: 1)

        #expect(retryWasCancelled)
        #expect(viewModel.state == .idle)
    }

    @Test
    func browseDetailScreenUsesScopedDependencies() {
        let dependencies = BrowseDependencies(
            service: BrowseService(items: [])
        )

        _ = BrowseDetailView(
            id: "swiftui",
            dependencies: dependencies
        )
    }
}
