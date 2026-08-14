import Foundation

nonisolated
enum StoreProductNotificationCategory {
    static func make() -> LocalNotificationCategory {
        LocalNotificationCategory(
            id: AppNotificationIdentifiers.storeCategory,
            actions: [
                .button(LocalNotificationButtonAction(
                    id: AppNotificationIdentifiers.openProductAction,
                    title: StoreServicesText.string("Open Product"),
                    options: .foreground
                )),
                .button(LocalNotificationButtonAction(
                    id: AppNotificationIdentifiers.favoriteAction,
                    title: StoreServicesText.string("Favorite"),
                    options: .foreground
                )),
                .button(LocalNotificationButtonAction(
                    id: AppNotificationIdentifiers.remindLaterAction,
                    title: StoreServicesText.string("Remind Later")
                ))
            ],
            reportsDismissal: true
        )
    }
}
