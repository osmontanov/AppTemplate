import Foundation
import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct RelatedItemsViewModelTests {
    @Test
    func relatedItemsExcludeTheSourceItem() async {
        let source = BrowseItem(id: "source", title: "Source", summary: "")
        let other = BrowseItem(id: "other", title: "Other", summary: "")
        let viewModel = RelatedItemsViewModel(
            sourceItemID: source.id,
            dependencies: BrowseDependencies(
                service: BrowseService(items: [source, other])
            ),
            router: FlowRouter()
        )

        await viewModel.load()

        #expect(viewModel.state == .content([other]))
    }

    @Test
    func onlyTheSourceItemProducesEmptyState() async {
        let source = BrowseItem(id: "source", title: "Source", summary: "")
        let viewModel = RelatedItemsViewModel(
            sourceItemID: source.id,
            dependencies: BrowseDependencies(
                service: BrowseService(items: [source])
            ),
            router: FlowRouter()
        )

        await viewModel.load()

        #expect(viewModel.state == .empty)
    }

    @Test
    func serviceFailureProducesDisplaySafeFailure() async {
        let viewModel = RelatedItemsViewModel(
            sourceItemID: "source",
            dependencies: BrowseDependencies(
                service: FailingBrowseService()
            ),
            router: FlowRouter()
        )

        await viewModel.load()

        #expect(viewModel.state == .failed(.load))
    }

    @Test
    func replacementLoadCancelsAndRejectsStaleResponse() async {
        let old = BrowseItem(id: "old", title: "Old", summary: "Slow")
        let new = BrowseItem(id: "new", title: "New", summary: "Current")
        let service = ControlledBrowseService()
        let viewModel = RelatedItemsViewModel(
            sourceItemID: "source",
            dependencies: BrowseDependencies(service: service),
            router: FlowRouter()
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
    func explicitCancellationRejectsNonCooperativeResponse() async {
        let item = BrowseItem(id: "late", title: "Late", summary: "")
        let service = ControlledBrowseService()
        let viewModel = RelatedItemsViewModel(
            sourceItemID: "source",
            dependencies: BrowseDependencies(service: service),
            router: FlowRouter()
        )

        let load = Task { await viewModel.load() }
        await service.waitForCalls(lists: 1)
        viewModel.cancel()
        await service.resumeItems(at: 0, returning: [item])
        await load.value
        let loadWasCancelled = await service.listWasCancelled(at: 0)

        #expect(loadWasCancelled)
        #expect(viewModel.state == .idle)
    }

    @Test
    func cancelledLoadTreatsOrdinaryServiceErrorAsCancellation() async {
        let service = ControlledBrowseService()
        let viewModel = RelatedItemsViewModel(
            sourceItemID: "source",
            dependencies: BrowseDependencies(service: service),
            router: FlowRouter()
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
    func retryThenDestinationCancellationCancelsOwnedLoad() async {
        let item = BrowseItem(id: "late", title: "Late", summary: "")
        let service = ControlledBrowseService()
        let viewModel = RelatedItemsViewModel(
            sourceItemID: "source",
            dependencies: BrowseDependencies(service: service),
            router: FlowRouter()
        )

        let initialLoad = Task { await viewModel.load() }
        await service.waitForCalls(lists: 1)
        await service.failItems(at: 0)
        await initialLoad.value
        #expect(viewModel.state == .failed(.load))

        let retry = viewModel.retry()
        await service.waitForCalls(lists: 2)
        viewModel.cancel()
        await service.resumeItems(at: 1, returning: [item])
        await retry.value
        let retryWasCancelled = await service.listWasCancelled(at: 1)

        #expect(retryWasCancelled)
        #expect(viewModel.state == .idle)
    }

    @Test
    func openingAnItemPushesTheRelatedItemsRoute() async {
        let source = BrowseItem(id: "source", title: "Source", summary: "")
        let other = BrowseItem(id: "other", title: "Other", summary: "")
        let router = FlowRouter()
        let dependencies = BrowseDependencies(
            service: BrowseService(items: [source, other])
        )
        let details = BrowseDetailViewModel(
            id: source.id,
            dependencies: dependencies,
            router: router
        )

        details.openRelatedItems()
        #expect(router.path.count == 1)

        router.popToRoot()
        let related = RelatedItemsViewModel(
            sourceItemID: source.id,
            dependencies: dependencies,
            router: router
        )
        await related.load()
        #expect(related.state == .content([other]))

        related.openItem(id: other.id)
        #expect(router.path.count == 1)
    }
}
