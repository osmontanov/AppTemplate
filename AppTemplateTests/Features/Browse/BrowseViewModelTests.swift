import Foundation
import Testing
@testable import AppTemplate

@MainActor
struct BrowseViewModelTests {
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
    func browseScreensUseScopedDependencies() {
        let dependencies = BrowseDependencies(
            service: BrowseService(items: [])
        )

        _ = BrowseNavigationView(
            router: BrowseRouter(),
            dependencies: dependencies
        )
        _ = BrowseDetailView(
            id: "swiftui",
            dependencies: dependencies
        )
    }
}

private nonisolated enum BrowseServiceTestError: Error {
    case failed
}

private actor FailingBrowseService: IBrowseService {
    func items() throws -> [BrowseItem] {
        throw BrowseServiceTestError.failed
    }

    func item(id: BrowseItem.ID) throws -> BrowseItem? {
        throw BrowseServiceTestError.failed
    }
}

private actor ControlledBrowseService: IBrowseService {
    private var listCount = 0
    private var detailCount = 0
    private var listContinuations:
        [Int: CheckedContinuation<[BrowseItem], any Error>] = [:]
    private var detailContinuations:
        [Int: CheckedContinuation<BrowseItem?, any Error>] = [:]
    private var listCancellations: [Int: Bool] = [:]
    private var detailCancellations: [Int: Bool] = [:]
    private var callWaiters: [CheckedContinuation<Void, Never>] = []

    func items() async throws -> [BrowseItem] {
        let index = listCount
        listCount += 1
        notifyCallWaiters()

        do {
            let items = try await withCheckedThrowingContinuation { continuation in
                listContinuations[index] = continuation
            }
            listCancellations[index] = Task.isCancelled
            return items
        } catch {
            listCancellations[index] = Task.isCancelled
            throw error
        }
    }

    func item(id: BrowseItem.ID) async throws -> BrowseItem? {
        let index = detailCount
        detailCount += 1
        notifyCallWaiters()

        do {
            let item = try await withCheckedThrowingContinuation { continuation in
                detailContinuations[index] = continuation
            }
            detailCancellations[index] = Task.isCancelled
            return item
        } catch {
            detailCancellations[index] = Task.isCancelled
            throw error
        }
    }

    func waitForCalls(lists: Int = 0, details: Int = 0) async {
        while listCount < lists || detailCount < details {
            await withCheckedContinuation { continuation in
                callWaiters.append(continuation)
            }
        }
    }

    func resumeItems(
        at index: Int,
        returning items: [BrowseItem]
    ) {
        listContinuations.removeValue(forKey: index)?.resume(
            returning: items
        )
    }

    func resumeItem(
        at index: Int,
        returning item: BrowseItem?
    ) {
        detailContinuations.removeValue(forKey: index)?.resume(
            returning: item
        )
    }

    func failItems(at index: Int) {
        listContinuations.removeValue(forKey: index)?.resume(
            throwing: BrowseServiceTestError.failed
        )
    }

    func failItem(at index: Int) {
        detailContinuations.removeValue(forKey: index)?.resume(
            throwing: BrowseServiceTestError.failed
        )
    }

    func listWasCancelled(at index: Int) -> Bool {
        listCancellations[index] == true
    }

    func detailWasCancelled(at index: Int) -> Bool {
        detailCancellations[index] == true
    }

    private func notifyCallWaiters() {
        let waiters = callWaiters
        callWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }
}
