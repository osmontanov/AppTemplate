nonisolated
struct CartAggregateQuery: Equatable, Sendable {
    init() {}
}

nonisolated
struct CartAggregate:
    LocalDatabaseModel,
    Codable,
    Equatable,
    Sendable
{
    typealias ID = String
    typealias Query = CartAggregateQuery
    typealias Persistence = CartAggregateAdapter

    static let singletonID = "Store.Cart"

    let id: String
    var revision: Int64
    var lines: [CartLine]

    init(id: String, revision: Int64, lines: [CartLine]) {
        self.id = id
        self.revision = revision
        self.lines = lines
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        revision = try container.decode(Int64.self, forKey: .revision)
        lines = try container.decode([CartLine].self, forKey: .lines)
        try validateStoreInvariants()
    }

    func validateStoreInvariants() throws {
        guard id == Self.singletonID else {
            throw StoreModelValidationError.invalidCartIdentity
        }
        guard revision >= 0 else {
            throw StoreModelValidationError.invalidRevision
        }
        var productIDs: Set<Int> = []
        for line in lines {
            try line.validateStoreInvariants()
            guard productIDs.insert(line.product.id).inserted else {
                throw StoreModelValidationError.duplicateCartProductID
            }
        }
    }
}
