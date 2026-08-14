import SwiftUI
import Testing
@testable import AppTemplate

struct StoreToolbarPolicyTests {
    @Test
    func compactToolbarKeepsPrimaryTasksAndReachableMore() {
        #expect(StoreToolbarPolicy.actions(horizontalSizeClass: .compact) == [
            .search, .filter, .cart, .more
        ])
    }

    @Test
    func regularAndUnspecifiedToolbarsKeepDirectDestinations() {
        let expected: [StoreToolbarAction] = [
            .search, .filter, .cart, .favorites, .profile
        ]
        #expect(StoreToolbarPolicy.actions(horizontalSizeClass: .regular) == expected)
        #expect(StoreToolbarPolicy.actions(horizontalSizeClass: nil) == expected)
        #expect(!expected.contains(.more))
    }
}
