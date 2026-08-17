import Foundation

nonisolated
enum AppNotificationIdentifiers {
    static let storeCategory = try! LocalNotificationCategoryID(
        "store.product-reminder"
    )
    static let openProductAction = try! LocalNotificationActionID(
        "store.product.open"
    )
    static let favoriteAction = try! LocalNotificationActionID(
        "store.product.favorite"
    )
    static let remindLaterAction = try! LocalNotificationActionID(
        "store.product.remind-later"
    )

    static func productRequest(
        _ productID: Product.ID
    ) throws -> LocalNotificationID {
        guard productID > 0 else { throw ProductReminderError.invalidProductID }
        return try LocalNotificationID("store.product-reminder.\(productID)")
    }

    static func productDeepLink(_ productID: Product.ID) throws -> URL {
        guard productID > 0,
              let url = URL(string: "\(AppURLScheme.scheme)://store/product/\(productID)") else {
            throw ProductReminderError.invalidProductID
        }
        return url
    }
}
