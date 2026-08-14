import SwiftUI

struct AppShellView: View {
    @Bindable var router: AppRouter
    let session: SessionPresentation
    let storeDependencies: StoreDependencies
    let storeUISupport: StoreUISupport
    let servicesDependencies: ServicesDependencies
    let sceneNavigation: any ISceneNavigationActions

    var body: some View {
        #if os(macOS)
        MacSidebarAppShellView(
            router: router,
            session: session,
            storeDependencies: storeDependencies,
            storeUISupport: storeUISupport,
            servicesDependencies: servicesDependencies,
            sceneNavigation: sceneNavigation
        )
        #else
        AdaptiveTabAppShellView(
            router: router,
            session: session,
            storeDependencies: storeDependencies,
            storeUISupport: storeUISupport,
            servicesDependencies: servicesDependencies,
            sceneNavigation: sceneNavigation
        )
        #endif
    }
}
