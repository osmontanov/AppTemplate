import SwiftUI

struct ServicesFlowView: View {
    @Bindable var router: ServicesRouter
    let dependencies: ServicesDependencies
    let sceneNavigation: any ISceneNavigationActions
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private let acceptsNavigationPathUpdates: @MainActor () -> Bool

    init(
        router: ServicesRouter,
        dependencies: ServicesDependencies,
        sceneNavigation: any ISceneNavigationActions,
        acceptsNavigationPathUpdates: @escaping @MainActor () -> Bool = { true }
    ) {
        self.router = router
        self.dependencies = dependencies
        self.sceneNavigation = sceneNavigation
        self.acceptsNavigationPathUpdates = acceptsNavigationPathUpdates
    }

    var body: some View {
        AdaptiveFlowNavigationContainer(
            path: Self.navigationPathBinding(
                router: router,
                acceptsUpdates: acceptsNavigationPathUpdates
            ),
            layout: AdaptiveFlowLayoutPolicy.resolve(horizontalSizeClass: horizontalSizeClass, isMacOS: isMacOS)
        ) {
            ServicesCatalogView(router: router)
        } placeholder: {
            ContentUnavailableView(StoreServicesText.resource("Select a Service"), systemImage: "wrench.and.screwdriver")
        } destination: { route in
            destination(for: route)
        }
    }

    @MainActor
    static func navigationPathBinding(
        router: ServicesRouter,
        acceptsUpdates: @escaping @MainActor () -> Bool
    ) -> Binding<[ServicesRoute]> {
        Binding(
            get: { router.path },
            set: { path in
                guard acceptsUpdates() else { return }
                router.path = path
            }
        )
    }

    @ViewBuilder
    private func destination(for route: ServicesRoute) -> some View {
        let item = catalogItem(for: route)
        switch route {
        case .appState:
            ServicesAppStateView(
                guide: item.guide,
                dependencies: dependencies,
                sceneNavigation: sceneNavigation
            )
        case .appInfo:
            ServicesAppInfoView(
                guide: item.guide,
                appInfo: dependencies.appInfo,
                platformName: platformName
            )
        case .userDefaults:
            UserDefaultsLabView(
                guide: item.guide,
                service: dependencies.userDefaultsLab
            )
        case .keychain:
            KeychainLabView(
                guide: item.guide,
                service: dependencies.keychainLab,
                session: dependencies.sessionActions
            )
        case .localDatabase:
            LocalDatabaseLabView(
                guide: item.guide,
                repository: dependencies.localDatabase
            )
        case .remoteAPI:
            RemoteAPILabView(
                guide: item.guide,
                remote: dependencies.remoteAPI,
                session: dependencies.sessionActions,
                diagnostics: dependencies.diagnostics
            )
        case .localNotifications:
            LocalNotificationLabView(
                guide: item.guide,
                lab: dependencies.notificationLab,
                appWide: dependencies.notificationAppWide,
                history: dependencies.notificationHistory,
                assets: dependencies.notificationAssets
            )
        }
    }

    private func catalogItem(for route: ServicesRoute) -> ServicesCatalogItem {
        guard let item = ServicesCatalogViewModel.items.first(where: {
            $0.route == route
        }) else {
            preconditionFailure("Every Services route must have one catalog guide")
        }
        return item
    }

    private var isMacOS: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }

    private var platformName: String {
        #if os(macOS)
        StoreServicesText.string("macOS")
        #elseif os(iOS)
        StoreServicesText.string("iOS")
        #else
        StoreServicesText.string("Apple Platform")
        #endif
    }
}
