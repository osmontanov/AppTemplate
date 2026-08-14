nonisolated
enum StoreProductNotificationCategory {
    static func make() -> LocalNotificationCategory {
        LocalNotificationCategory(
            id: AppNotificationIdentifiers.storeCategory,
            actions: [
                .button(LocalNotificationButtonAction(
                    id: AppNotificationIdentifiers.openProductAction,
                    title: "Open Product",
                    options: .foreground
                )),
                .button(LocalNotificationButtonAction(
                    id: AppNotificationIdentifiers.favoriteAction,
                    title: "Favorite",
                    options: .foreground
                )),
                .button(LocalNotificationButtonAction(
                    id: AppNotificationIdentifiers.remindLaterAction,
                    title: "Remind Later"
                ))
            ],
            reportsDismissal: true
        )
    }
}
