import SwiftUI

struct AppShellView: View {
    @Bindable var router: AppRouter
    let storeDependencies: StoreDependencies
    let storeUISupport: StoreUISupport
    let storeCatalogViewModel: CatalogViewModel
    let servicesDependencies: ServicesDependencies
    let sceneNavigation: any ISceneNavigationActions

    var body: some View {
        #if os(macOS)
        MacSidebarAppShellView(
            router: router,
            storeDependencies: storeDependencies,
            storeUISupport: storeUISupport,
            storeCatalogViewModel: storeCatalogViewModel,
            servicesDependencies: servicesDependencies,
            sceneNavigation: sceneNavigation
        )
        #else
        AdaptiveTabAppShellView(
            router: router,
            storeDependencies: storeDependencies,
            storeUISupport: storeUISupport,
            storeCatalogViewModel: storeCatalogViewModel,
            servicesDependencies: servicesDependencies,
            sceneNavigation: sceneNavigation
        )
        #endif
    }
}
