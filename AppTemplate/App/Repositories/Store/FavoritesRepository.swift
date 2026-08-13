actor FavoritesRepository: IFavoritesRepository {
    private let database: any ILocalDatabaseService
    private let gate = AsyncOperationGate()

    init(database: any ILocalDatabaseService) {
        self.database = database
    }

    func favorites(userID: Int) async throws -> [FavoriteProductSnapshot] {
        try await database.fetch(
            FavoriteProductSnapshot.self,
            matching: FavoriteProductQuery(userID: userID)
        ).sorted { $0.product.id < $1.product.id }
    }

    func contains(userID: Int, productID: Int) async throws -> Bool {
        let id = FavoriteProductSnapshot.canonicalID(
            userID: userID,
            productID: productID
        )
        return try await database.fetch(FavoriteProductSnapshot.self, id: id) != nil
    }

    func ensureFavorite(
        _ product: ProductSnapshot,
        userID: Int
    ) async throws -> Bool {
        let database = database
        return try await gate.withExclusiveAccess {
            try await Self.ensureFavorite(product, userID: userID, database: database)
        }
    }

    func removeFavorite(userID: Int, productID: Int) async throws -> Bool {
        let database = database
        return try await gate.withExclusiveAccess {
            let id = FavoriteProductSnapshot.canonicalID(
                userID: userID,
                productID: productID
            )
            return try await database.delete(FavoriteProductSnapshot.self, id: id)
        }
    }

    func toggle(_ product: ProductSnapshot, userID: Int) async throws -> Bool {
        let database = database
        return try await gate.withExclusiveAccess {
            let id = FavoriteProductSnapshot.canonicalID(
                userID: userID,
                productID: product.id
            )
            if try await database.fetch(FavoriteProductSnapshot.self, id: id) != nil {
                _ = try await database.delete(FavoriteProductSnapshot.self, id: id)
                return false
            }
            return try await Self.ensureFavorite(product, userID: userID, database: database)
        }
    }

    private nonisolated static func ensureFavorite(
        _ product: ProductSnapshot,
        userID: Int,
        database: any ILocalDatabaseService
    ) async throws -> Bool {
        let id = FavoriteProductSnapshot.canonicalID(
            userID: userID,
            productID: product.id
        )
        guard try await database.fetch(FavoriteProductSnapshot.self, id: id) == nil else {
            return false
        }
        try await database.upsert(
            FavoriteProductSnapshot(canonicalID: id, userID: userID, product: product)
        )
        return true
    }
}
