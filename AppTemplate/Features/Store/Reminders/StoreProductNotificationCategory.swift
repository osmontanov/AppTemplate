import Foundation

nonisolated
enum StoreProductNotificationCategory {
    static func make() -> LocalNotificationCategory {
        LocalNotificationCategory(
            id: AppNotificationIdentifiers.storeCategory,
            actions: [
                .button(LocalNotificationButtonAction(
                    id: AppNotificationIdentifiers.openProductAction,
                    title: AppText.string("Open Product"),
                    options: .foreground
                )),
                .button(LocalNotificationButtonAction(
                    id: AppNotificationIdentifiers.favoriteAction,
                    title: AppText.string("Favorite"),
                    options: .foreground
                )),
                .button(LocalNotificationButtonAction(
                    id: AppNotificationIdentifiers.remindLaterAction,
                    title: AppText.string("Remind Later")
                ))
            ],
            reportsDismissal: true
        )
    }
}
