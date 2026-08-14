import Foundation
import Testing
@testable import AppTemplate

@MainActor
struct FavoritesViewModelTests {
    @Test
    func loadReadsOnlyTheExplicitUsersFavorites() async {
        let repository = FavoritesRepositorySpy(favorites: [favorite(userID: 7, productID: 2)])
        let viewModel = FavoritesViewModel(repository: repository)

        await viewModel.load(userID: 7)

        #expect(await repository.readUserIDs == [7])
        #expect(viewModel.state == .loaded(FavoritesModel(items: [favorite(userID: 7, productID: 2)])))
    }

    @Test
    func removePublishesOnlyAfterSuccessfulUserScopedWrite() async {
        let gate = FavoritesWriteGate()
        let item = favorite(userID: 7, productID: 2)
        let repository = FavoritesRepositorySpy(favorites: [item], removeGate: gate)
        let viewModel = FavoritesViewModel(repository: repository)
        await viewModel.load(userID: 7)

        let task = Task { await viewModel.remove(productID: 2, userID: 7) }
        await gate.waitUntilEntered()
        #expect(viewModel.state == .loaded(FavoritesModel(items: [item])))

        await gate.resolve(.success(true))
        await task.value

        #expect(await repository.removeCalls.map(\.userID) == [7])
        #expect(await repository.removeCalls.map(\.productID) == [2])
        #expect(viewModel.state == .empty)
    }

    @Test
    func failedRemoveKeepsTheSavedFavoriteVisible() async {
        let item = favorite(userID: 9, productID: 3)
        let repository = FavoritesRepositorySpy(
            favorites: [item],
            removeResults: [.failure(FavoritesTestError.injected)]
        )
        let viewModel = FavoritesViewModel(repository: repository)
        await viewModel.load(userID: 9)

        await viewModel.remove(productID: 3, userID: 9)

        #expect(viewModel.state == .loaded(FavoritesModel(items: [item])))
        #expect(viewModel.error == .writeFailed)
    }

    @Test
    func failedReadPublishesTypedFailure() async {
        let repository = FavoritesRepositorySpy(readError: FavoritesTestError.injected)
        let viewModel = FavoritesViewModel(repository: repository)

        await viewModel.load(userID: 1)

        #expect(viewModel.state == .failed)
        #expect(viewModel.error == .readFailed)
    }

    private func favorite(userID: Int, productID: Int) -> FavoriteProductSnapshot {
        Self.favorite(userID: userID, productID: productID)
    }

    private static func favorite(userID: Int, productID: Int) -> FavoriteProductSnapshot {
        let product = ProductSnapshot(id: productID, title: "Product \(productID)", price: 5, thumbnailURL: nil)
        return FavoriteProductSnapshot(
            canonicalID: FavoriteProductSnapshot.canonicalID(userID: userID, productID: productID),
            userID: userID,
            product: product
        )
    }
}

private enum FavoritesTestError: Error { case injected }

private actor FavoritesRepositorySpy: IFavoritesRepository {
    private(set) var readUserIDs: [Int] = []
    private(set) var removeCalls: [(userID: Int, productID: Int)] = []
    private var storedFavorites: [FavoriteProductSnapshot]
    private let readError: Error?
    private var removeResults: [Result<Bool, Error>]
    private let removeGate: FavoritesWriteGate?

    init(
        favorites: [FavoriteProductSnapshot] = [],
        readError: Error? = nil,
        removeResults: [Result<Bool, Error>] = [],
        removeGate: FavoritesWriteGate? = nil
    ) {
        storedFavorites = favorites
        self.readError = readError
        self.removeResults = removeResults
        self.removeGate = removeGate
    }

    func favorites(userID: Int) async throws -> [FavoriteProductSnapshot] {
        readUserIDs.append(userID)
        if let readError { throw readError }
        return storedFavorites.filter { $0.userID == userID }
    }

    func contains(userID: Int, productID: Int) async throws -> Bool {
        storedFavorites.contains { $0.userID == userID && $0.product.id == productID }
    }

    func ensureFavorite(_ product: ProductSnapshot, userID: Int) async throws -> Bool { false }

    func removeFavorite(userID: Int, productID: Int) async throws -> Bool {
        removeCalls.append((userID, productID))
        if let removeGate {
            return try await removeGate.wait().get()
        }
        if !removeResults.isEmpty { return try removeResults.removeFirst().get() }
        let previous = storedFavorites.count
        storedFavorites.removeAll { $0.userID == userID && $0.product.id == productID }
        return previous != storedFavorites.count
    }

    func toggle(_ product: ProductSnapshot, userID: Int) async throws -> Bool { false }
}

private actor FavoritesWriteGate {
    private var entered = false
    private var result: Result<Bool, Error>?
    private var entryWaiters: [CheckedContinuation<Void, Never>] = []
    private var resultWaiters: [CheckedContinuation<Result<Bool, Error>, Never>] = []

    func wait() async -> Result<Bool, Error> {
        entered = true
        entryWaiters.forEach { $0.resume() }
        entryWaiters.removeAll()
        if let result { return result }
        return await withCheckedContinuation { resultWaiters.append($0) }
    }

    func waitUntilEntered() async {
        guard !entered else { return }
        await withCheckedContinuation { entryWaiters.append($0) }
    }

    func resolve(_ value: Result<Bool, Error>) {
        result = value
        resultWaiters.forEach { $0.resume(returning: value) }
        resultWaiters.removeAll()
    }
}
