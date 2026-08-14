nonisolated
struct ProductReminderMetadata: Equatable, Sendable {
    private static let productIDKey = "productID"

    let productID: Product.ID

    init(productID: Product.ID) throws {
        guard productID > 0 else { throw ProductReminderError.invalidProductID }
        self.productID = productID
    }

    static func decode(
        _ values: [String: LocalNotificationMetadataValue]
    ) throws -> Self {
        guard values.count == 1,
              case let .integer(rawProductID)? = values[productIDKey],
              let productID = Product.ID(exactly: rawProductID),
              productID > 0 else {
            throw ProductReminderError.invalidRescheduleSource
        }
        return try Self(productID: productID)
    }

    var notificationValues: [String: LocalNotificationMetadataValue] {
        [Self.productIDKey: .integer(Int64(productID))]
    }
}
