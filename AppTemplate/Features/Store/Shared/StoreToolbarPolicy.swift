import SwiftUI

nonisolated
enum StoreToolbarAction: Equatable, Sendable {
    case search, filter, cart, favorites, profile, more
}

nonisolated
enum StoreToolbarPolicy {
    static func actions(horizontalSizeClass: UserInterfaceSizeClass?) -> [StoreToolbarAction] {
        horizontalSizeClass == .compact
            ? [.search, .filter, .cart, .more]
            : [.search, .filter, .cart, .favorites, .profile]
    }
}
