import Observation

@MainActor
@Observable
final class BrowseListStore {
    private(set) var state: BrowseListState = .idle
    private let repository: any BrowseRepository
    private var requestVersion = 0

    init(repository: any BrowseRepository) {
        self.repository = repository
    }

    func load() async {
        requestVersion += 1
        let version = requestVersion
        state = .loading

        do {
            let items = try await repository.items()
            guard version == requestVersion else {
                return
            }
            state = .content(items)
        } catch is CancellationError {
            guard version == requestVersion else {
                return
            }
            state = .idle
        } catch {
            guard version == requestVersion else {
                return
            }
            state = .failed(.load)
        }
    }
}
