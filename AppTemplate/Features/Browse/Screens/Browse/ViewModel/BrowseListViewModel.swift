import Observation

@MainActor
@Observable
final class BrowseListViewModel {
    private(set) var state: BrowseListState = .idle
    private let dependencies: BrowseDependencies
    private let router: any IFlowRouter
    private var requestVersion = 0
    private var loadTask: Task<Void, Never>?

    init(
        dependencies: BrowseDependencies,
        router: any IFlowRouter
    ) {
        self.dependencies = dependencies
        self.router = router
    }

    func openItem(id: BrowseItem.ID) {
        router.push(BrowseRoute.item(id: id))
    }

    func load() async {
        let task = beginLoad()
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    @discardableResult
    func retry() -> Task<Void, Never> {
        beginLoad()
    }

    func cancel() {
        requestVersion += 1
        loadTask?.cancel()
        loadTask = nil
        if state == .loading {
            state = .idle
        }
    }

    private func beginLoad() -> Task<Void, Never> {
        requestVersion += 1
        let version = requestVersion
        loadTask?.cancel()
        state = .loading

        let service = dependencies.service
        let task = Task { @MainActor [weak self, service] in
            do {
                let items = try await service.items()
                try Task.checkCancellation()
                self?.finish(items, version: version)
            } catch is CancellationError {
                self?.finishCancellation(version: version)
            } catch {
                if Task.isCancelled {
                    self?.finishCancellation(version: version)
                } else {
                    self?.finishFailure(version: version)
                }
            }
        }
        loadTask = task
        return task
    }

    private func finish(_ items: [BrowseItem], version: Int) {
        guard version == requestVersion else {
            return
        }
        loadTask = nil
        state = items.isEmpty ? .empty : .content(items)
    }

    private func finishCancellation(version: Int) {
        guard version == requestVersion else {
            return
        }
        loadTask = nil
        state = .idle
    }

    private func finishFailure(version: Int) {
        guard version == requestVersion else {
            return
        }
        loadTask = nil
        state = .failed(.load)
    }
}
