import Testing
@testable import AppTemplate

struct StoreProductNotificationCategoryTests {
    @Test
    func storeCategoryHasFrozenProductAgnosticActions() throws {
        let category = StoreProductNotificationCategory.make()
        let buttons = category.actions.compactMap { action -> LocalNotificationButtonAction? in
            guard case let .button(button) = action else { return nil }
            return button
        }

        try #require(buttons.count == 3)
        #expect(category.id.value == "store.product-reminder")
        #expect(buttons.map(\.id.value) == [
            "store.product.open",
            "store.product.favorite",
            "store.product.remind-later"
        ])
        #expect(buttons.map(\.title) == ["Open Product", "Favorite", "Remind Later"])
        #expect(buttons.map(\.options) == [.foreground, .foreground, []])
        #expect(buttons[1].options.contains(.foreground))
        #expect(!buttons[1].options.contains(.authenticationRequired))
        #expect(buttons.allSatisfy { $0.deepLink == nil })
        #expect(category.reportsDismissal)
        #expect(category.hiddenPreviewsBodyPlaceholder == nil)
        #expect(category.categorySummaryFormat == nil)
        #expect(!category.hiddenPreviewsShowTitle)
        #expect(!category.hiddenPreviewsShowSubtitle)
    }
}
