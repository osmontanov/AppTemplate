import Foundation
import Testing
@testable import AppTemplate

struct FavoritesRepositoryTests {
    @Test
    func favoritesAreSortedByProductIDAndContainsUsesCanonicalID() async throws {
        let database = makeStoreDatabase()
        try await database.upsert([
            favorite(userID: 4, productID: 9),
            favorite(userID: 4, productID: 2),
            favorite(userID: 5, productID: 1)
        ])
        let repository = FavoritesRepository(database: database)

        let values = try await repository.favorites(userID: 4)

        #expect(values.map(\.product.id) == [2, 9])
        #expect(try await repository.contains(userID: 4, productID: 9))
        #expect(!(try await repository.contains(userID: 4, productID: 1)))
    }

    @Test
    func concurrentEnsureFavoriteInsertsOneCanonicalRow() async throws {
        let database = makeStoreDatabase()
        let repository = FavoritesRepository(database: database)
        let snapshot = product(7)

        let recorder = FavoriteBoolRecorder()
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<12 {
                group.addTask {
                    await recorder.record(
                        try await repository.ensureFavorite(snapshot, userID: 3)
                    )
                }
            }
            try await group.waitForAll()
        }
        let results = await recorder.values

        #expect(results.filter { $0 }.count == 1)
        #expect(results.filter { !$0 }.count == 11)
        let rows = try await database.fetch(
            FavoriteProductSnapshot.self,
            matching: FavoriteProductQuery(userID: 3)
        )
        #expect(rows.count == 1)
        #expect(rows.first?.id == "user:3|product:7")
    }

    @Test
    func existingFavoriteIsNotOverwrittenAndRemoveAndToggleReportResultingState() async throws {
        let database = makeStoreDatabase()
        let repository = FavoritesRepository(database: database)
        let original = product(8, title: "Original")
        #expect(try await repository.ensureFavorite(original, userID: 2))

        #expect(!(try await repository.ensureFavorite(product(8, title: "Changed"), userID: 2)))
        #expect(try await repository.favorites(userID: 2).first?.product.title == "Original")
        #expect(!(try await repository.removeFavorite(userID: 2, productID: 99)))
        #expect(!(try await repository.toggle(original, userID: 2)))
        #expect(try await repository.toggle(original, userID: 2))
        #expect(try await repository.removeFavorite(userID: 2, productID: 8))
    }

    @Test
    func adapterValidationRejectsInvalidUserProductAndSnapshot() async {
        let repository = FavoritesRepository(database: makeStoreDatabase())

        await #expect(throws: (any Error).self) {
            try await repository.ensureFavorite(product(1), userID: 0)
        }
        await #expect(throws: (any Error).self) {
            try await repository.ensureFavorite(product(0), userID: 1)
        }
        await #expect(throws: (any Error).self) {
            try await repository.ensureFavorite(product(1, price: -1), userID: 1)
        }
    }
}

private actor FavoriteBoolRecorder {
    private(set) var values: [Bool] = []
    func record(_ value: Bool) { values.append(value) }
}

private func makeStoreDatabase() -> any ILocalDatabaseService {
    LocalDatabaseService(configuration: .inMemory())
}

private func product(
    _ id: Int,
    title: String? = nil,
    price: Decimal = 1
) -> ProductSnapshot {
    ProductSnapshot(
        id: id,
        title: title ?? "Product \(id)",
        price: price,
        thumbnailURL: nil
    )
}

private func favorite(userID: Int, productID: Int) -> FavoriteProductSnapshot {
    FavoriteProductSnapshot(
        canonicalID: FavoriteProductSnapshot.canonicalID(
            userID: userID,
            productID: productID
        ),
        userID: userID,
        product: product(productID)
    )
}
