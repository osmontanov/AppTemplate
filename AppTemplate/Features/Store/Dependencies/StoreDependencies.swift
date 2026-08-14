@MainActor
struct StoreDependencies: Sendable {
    let products: any IProductRepository
    let cart: any ICartRepository
    let preferences: any IStorePreferencesRepository
    let appInfo: any IAppInfoService
}

nonisolated
struct StoreUISupport: Sendable {
    let images: any IImageLoader
    let clock: AppClock
}
