nonisolated
enum AppAccessibilityIdentifier {
    nonisolated enum Screen: String, CaseIterable, Sendable {
        case storeCatalog, productDetail, reviews, cart, checkout, authentication
        case sessionRecovery, favorites, profile, storePreferences, productReminder
        case servicesCatalog, serviceLab, onboarding, maintenance, restoring
    }

    nonisolated enum Action: String, CaseIterable, Sendable {
        case tryService, resetService, scheduleReminder, favorite
        case signIn, signOut, cancel, continueCheckout
    }

    nonisolated enum ResultRole: String, CaseIterable, Sendable {
        case actualSuccess, actualFailure, loading, empty
    }

    nonisolated enum ServiceDestination: String, CaseIterable, Sendable {
        case appState, appInfo, userDefaults, keychain, localDatabase, remoteAPI
        case localNotifications
    }

    static func screen(_ value: Screen) -> String {
        switch value {
        case .storeCatalog: "screen.store.catalog"
        case .productDetail: "screen.store.product"
        case .reviews: "screen.store.reviews"
        case .cart: "screen.store.cart"
        case .checkout: "screen.store.checkout"
        case .authentication: "screen.authentication"
        case .sessionRecovery: "screen.session-recovery"
        case .favorites: "screen.store.favorites"
        case .profile: "screen.store.profile"
        case .storePreferences: "screen.store.settings"
        case .productReminder: "screen.store.product-reminder"
        case .servicesCatalog: "screen.services.root"
        case .serviceLab: "screen.services.lab"
        case .onboarding: "screen.onboarding"
        case .maintenance: "screen.maintenance"
        case .restoring: "screen.session-restoring"
        }
    }

    static func action(_ value: Action) -> String {
        switch value {
        case .tryService: "action.service.try"
        case .resetService: "action.service.reset"
        case .scheduleReminder: "action.product-reminder.schedule"
        case .favorite: "action.store.favorite"
        case .signIn: "action.authentication.sign-in"
        case .signOut: "action.store.sign-out"
        case .cancel: "action.cancel"
        case .continueCheckout: "action.store.checkout.continue"
        }
    }

    static func result(_ value: ResultRole) -> String {
        switch value {
        case .actualSuccess: "result.actual.success"
        case .actualFailure: "result.actual.failure"
        case .loading: "result.loading"
        case .empty: "result.empty"
        }
    }

    static func serviceDestination(_ value: ServiceDestination) -> String {
        switch value {
        case .appState: "service.app-state"
        case .appInfo: "service.app-info"
        case .userDefaults: "service.user-defaults"
        case .keychain: "service.keychain"
        case .localDatabase: "service.local-database"
        case .remoteAPI: "service.remote-api"
        case .localNotifications: "service.local-notifications"
        }
    }
}
