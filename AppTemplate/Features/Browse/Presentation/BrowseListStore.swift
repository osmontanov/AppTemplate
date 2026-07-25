import Observation

@MainActor
@Observable
final class BrowseListStore {
    private(set) var state: BrowseListState = .idle
    private let repository: any BrowseRepository
    private var requestVersion = 0
    private var loadTask: Task<Void, Never>?

    init(repository: any BrowseRepository) {
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
        let task = Task { @MainActor [weak self, repository] in
            do {
                let items = try await repository.items()
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
        state = .content(items)
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
