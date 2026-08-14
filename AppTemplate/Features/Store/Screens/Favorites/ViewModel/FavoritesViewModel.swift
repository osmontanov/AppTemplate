import Observation

@MainActor
@Observable
final class FavoritesViewModel {
    private let repository: any IFavoritesRepository
    private(set) var state: FavoritesState = .idle
    private(set) var error: FavoritesError?

    init(repository: any IFavoritesRepository) {
        self.repository = repository
    }

    func load(userID: Int) async {
        state = .loading
        error = nil
        do {
            let items = try await repository.favorites(userID: userID)
            try Task.checkCancellation()
            state = items.isEmpty ? .empty : .loaded(FavoritesModel(items: items))
        } catch is CancellationError {
            return
        } catch {
            self.error = .readFailed
            state = .failed
        }
    }

    func remove(productID: Product.ID, userID: Int) async {
        guard case let .loaded(model) = state else { return }
        do {
            _ = try await repository.removeFavorite(
                userID: userID,
                productID: productID
            )
            try Task.checkCancellation()
            let items = model.items.filter { $0.product.id != productID }
            error = nil
            state = items.isEmpty ? .empty : .loaded(FavoritesModel(items: items))
        } catch is CancellationError {
            return
        } catch {
            self.error = .writeFailed
        }
    }
}
