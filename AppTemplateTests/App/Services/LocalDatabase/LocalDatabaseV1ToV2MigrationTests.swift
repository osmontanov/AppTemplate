import Foundation
import SwiftData
import Testing
@testable import AppTemplate

@Suite(.serialized)
struct LocalDatabaseV1ToV2MigrationTests {
    @Test
    func v1DiskReopensWithoutRewritingAndV2EntitiesRemainUsable() async throws {
        let payload = "legacy 😀 café"
        let legacyID = " Legacy-Ж "
        let url = try uniqueLocalDatabaseStoreURL(label: "v1-to-v2")
        try writeFrozenV1Record(id: legacyID, payload: payload, at: url)

        let service = LocalDatabaseService(configuration: .disk(url: url))
        let legacy = try await service.fetch(ExampleRecord.self, id: legacyID)

        #expect(legacy?.id == legacyID)
        #expect(legacy.map { Data($0.payload.utf8) } == Data(payload.utf8))

        let product = ProductSnapshot(
            id: 17,
            title: "Кыргыз чайы 😀",
            price: Decimal(string: "42.125")!,
            thumbnailURL: URL(string: "https://example.com/чай.png")
        )
        let favorite = FavoriteProductSnapshot(
            canonicalID: FavoriteProductSnapshot.canonicalID(
                userID: 9,
                productID: product.id
            ),
            userID: 9,
            product: product
        )
        let cart = CartAggregate(
            id: CartAggregate.singletonID,
            revision: 3,
            lines: [CartLine(product: product, quantity: 2)]
        )

        try await service.upsert(favorite)
        try await service.upsert(cart)

        #expect(
            try await service.fetch(
                FavoriteProductSnapshot.self,
                id: favorite.id
            ) == favorite
        )
        #expect(
            try await service.fetch(
                CartAggregate.self,
                id: CartAggregate.singletonID
            ) == cart
        )
        #expect(LocalDatabaseModelRegistry.production.registrationCount == 3)
        #expect(
            LocalDatabaseModelRegistry.production.registeredEntityIdentifiers
                == Set(LocalDatabaseSchemaV2.models.map(ObjectIdentifier.init))
        )
    }

    @Test
    func detachedStoreModelsRejectInvalidDomainInvariantsDuringDecode() throws {
        let decoder = JSONDecoder()

        #expect(throws: StoreModelValidationError.self) {
            _ = try decoder.decode(
                ProductSnapshot.self,
                from: Data(#"{"id":0,"title":"bad","price":1}"#.utf8)
            )
        }
        #expect(throws: StoreModelValidationError.self) {
            _ = try decoder.decode(
                CartLine.self,
                from: Data(
                    #"{"product":{"id":1,"title":"ok","price":1},"quantity":0}"#.utf8
                )
            )
        }
        #expect(throws: StoreModelValidationError.self) {
            _ = try decoder.decode(
                CartAggregate.self,
                from: Data(
                    #"{"id":"Store.Cart","revision":0,"lines":[{"product":{"id":1,"title":"a","price":1},"quantity":1},{"product":{"id":1,"title":"b","price":2},"quantity":2}]}"#.utf8
                )
            )
        }
    }

    @Test
    func adaptersRejectMismatchedIdentitiesInsteadOfRepairingThem() throws {
        let product = validProduct()
        let favorite = FavoriteProductSnapshot(
            canonicalID: "user:2|product:8",
            userID: 2,
            product: product
        )
        #expect(throws: StoreModelValidationError.self) {
            try FavoriteProductSnapshotAdapter.validate(value: favorite)
        }

        let cart = CartAggregate(id: "cart", revision: 0, lines: [])
        #expect(throws: StoreModelValidationError.self) {
            try CartAggregateAdapter.validate(value: cart)
        }
    }

    @Test
    func adapterEncodingLimitsAcceptBoundaryAndRejectOneByteOver() throws {
        let favoriteAtLimit = favoriteWithEncodedSnapshotSize(64 * 1_024)
        let favoriteOverLimit = favoriteWithEncodedSnapshotSize(64 * 1_024 + 1)
        try FavoriteProductSnapshotAdapter.validate(value: favoriteAtLimit)
        #expect(throws: StorePersistenceValidationError.self) {
            try FavoriteProductSnapshotAdapter.validate(value: favoriteOverLimit)
        }

        let cartAtLimit = cartWithEncodedLinesSize(256 * 1_024)
        let cartOverLimit = cartWithEncodedLinesSize(256 * 1_024 + 1)
        try CartAggregateAdapter.validate(value: cartAtLimit)
        #expect(throws: StorePersistenceValidationError.self) {
            try CartAggregateAdapter.validate(value: cartOverLimit)
        }
    }

    @Test
    func adapterDecodingLimitsAcceptBoundaryAndRejectOneByteOver() throws {
        let favorite = favoriteWithEncodedSnapshotSize(64 * 1_024)
        let cart = cartWithEncodedLinesSize(256 * 1_024)
        try FavoriteProductSnapshotAdapter.validate(value: favorite)
        try CartAggregateAdapter.validate(value: cart)

        let container = try LocalDatabaseContainerFactories.inMemory()()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let favoriteEntity = FavoriteProductSnapshotAdapter.makeEntity(
            from: favorite
        )
        let cartEntity = CartAggregateAdapter.makeEntity(from: cart)
        context.insert(favoriteEntity)
        context.insert(cartEntity)
        try context.save()

        #expect(
            try FavoriteProductSnapshotAdapter.fetch(
                id: favorite.id,
                in: context
            ).map(FavoriteProductSnapshotAdapter.value(from:)) == favorite
        )
        #expect(
            try CartAggregateAdapter.fetch(
                id: cart.id,
                in: context
            ).map(CartAggregateAdapter.value(from:)) == cart
        )

        favoriteEntity.snapshotData.append(0x20)
        cartEntity.linesData.append(0x20)
        #expect(throws: StorePersistenceValidationError.self) {
            _ = try FavoriteProductSnapshotAdapter.fetch(
                id: favorite.id,
                in: context
            )
        }
        #expect(throws: StorePersistenceValidationError.self) {
            _ = try CartAggregateAdapter.fetch(id: cart.id, in: context)
        }
    }

    @Test
    func fetchPathsRejectOversizeAndCorruptStoredData() throws {
        let container = try LocalDatabaseContainerFactories.inMemory()()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        context.insert(
            LocalDatabaseSchemaV2.StoredFavoriteProductSnapshot(
                canonicalID: "user:1|product:1",
                userID: 1,
                productID: 1,
                snapshotData: Data(repeating: 0x20, count: 64 * 1_024 + 1)
            )
        )
        context.insert(
            LocalDatabaseSchemaV2.StoredCartAggregate(
                id: CartAggregate.singletonID,
                revision: 0,
                linesData: Data(#"[{"product":{"id":1,"title":"x","price":1},"quantity":0}]"#.utf8)
            )
        )
        try context.save()

        #expect(throws: StorePersistenceValidationError.self) {
            _ = try FavoriteProductSnapshotAdapter.fetch(
                id: "user:1|product:1",
                in: context
            )
        }
        #expect(throws: StoreModelValidationError.self) {
            _ = try CartAggregateAdapter.fetch(
                id: CartAggregate.singletonID,
                in: context
            )
        }
    }

    private func writeFrozenV1Record(
        id: String,
        payload: String,
        at url: URL
    ) throws {
        let schema = Schema(versionedSchema: LocalDatabaseSchemaV1.self)
        let configuration = ModelConfiguration(
            "FrozenV1",
            schema: schema,
            url: url,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        let context = ModelContext(container)
        context.autosaveEnabled = false
        context.insert(
            LocalDatabaseSchemaV1.StoredExampleRecord(
                id: id,
                payload: payload
            )
        )
        try context.save()
    }

    private func validProduct(title: String = "Tea") -> ProductSnapshot {
        ProductSnapshot(
            id: 7,
            title: title,
            price: Decimal(string: "12.50")!,
            thumbnailURL: URL(string: "https://example.com/tea.png")
        )
    }

    private func favoriteWithEncodedSnapshotSize(
        _ targetSize: Int
    ) -> FavoriteProductSnapshot {
        let baseSize = encodedSize(of: validProduct(title: ""))
        let product = validProduct(
            title: String(repeating: "a", count: targetSize - baseSize)
        )
        #expect(encodedSize(of: product) == targetSize)
        return FavoriteProductSnapshot(
            canonicalID: "user:2|product:7",
            userID: 2,
            product: product
        )
    }

    private func cartWithEncodedLinesSize(_ targetSize: Int) -> CartAggregate {
        let emptyTitleLine = CartLine(product: validProduct(title: ""), quantity: 1)
        let baseSize = encodedSize(of: [emptyTitleLine])
        let line = CartLine(
            product: validProduct(
                title: String(repeating: "a", count: targetSize - baseSize)
            ),
            quantity: 1
        )
        #expect(encodedSize(of: [line]) == targetSize)
        return CartAggregate(
            id: CartAggregate.singletonID,
            revision: 0,
            lines: [line]
        )
    }

    private func encodedSize<Value: Encodable>(of value: Value) -> Int {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try! encoder.encode(value).count
    }
}
