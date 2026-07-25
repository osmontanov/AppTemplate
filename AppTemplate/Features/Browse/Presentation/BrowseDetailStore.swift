import Observation

@MainActor
@Observable
final class BrowseDetailStore {
    let id: BrowseItem.ID
    private(set) var state: BrowseDetailState = .idle
    private let repository: any BrowseRepository
    private var requestVersion = 0
    private var loadTask: Task<Void, Never>?

    init(id: BrowseItem.ID, repository: any BrowseRepository) {
        self.id = id
        self.repository = repository
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

        let repository = repository
        let id = id
        let task = Task { @MainActor [weak self, repository, id] in
            do {
                let item = try await repository.item(id: id)
                try Task.checkCancellation()
                self?.finish(item, version: version)
            } catch is CancellationError {
                self?.finishCancellation(version: version)
            } catch {
                self?.finishFailure(version: version)
            }
        }
        loadTask = task
        return task
    }

    private func finish(_ item: BrowseItem?, version: Int) {
        guard version == requestVersion else {
            return
        }
        loadTask = nil
        state = item.map(BrowseDetailState.content) ?? .notFound
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
