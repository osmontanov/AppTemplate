@MainActor
struct StoreDependencies: Sendable {
    let products: any IProductRepository
    let session: any ISessionActions
    let favorites: any IFavoritesRepository
    let cart: any ICartRepository
    let preferences: any IStorePreferencesRepository
    let reminders: any IProductReminderRepository
    let appInfo: any IAppInfoService
}

nonisolated
struct StoreUISupport: Sendable {
    let images: any IImageLoader
    let clock: AppClock
}
