import Observation

@MainActor
@Observable
final class BrowseDetailStore {
    let id: BrowseItem.ID
    private(set) var state: BrowseDetailState = .idle
    private let repository: any BrowseRepository
    private var requestVersion = 0

    init(id: BrowseItem.ID, repository: any BrowseRepository) {
        self.id = id
        self.repository = repository
    }

    func load() async {
        requestVersion += 1
        let version = requestVersion
        state = .loading

        do {
            let item = try await repository.item(id: id)
            guard version == requestVersion else {
                return
            }
            state = item.map(BrowseDetailState.content) ?? .notFound
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

    func cancel() {
        requestVersion += 1
        if state == .loading {
            state = .idle
        }
    }
}
