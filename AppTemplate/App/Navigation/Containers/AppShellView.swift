import SwiftUI

struct AppShellView: View {
    @Bindable var router: AppRouter
    let session: SessionPresentation
    let storeDependencies: StoreDependencies
    let storeUISupport: StoreUISupport

    var body: some View {
        #if os(macOS)
        MacSidebarAppShellView(
            router: router,
            session: session,
            storeDependencies: storeDependencies,
            storeUISupport: storeUISupport
        )
        #else
        AdaptiveTabAppShellView(
            router: router,
            session: session,
            storeDependencies: storeDependencies,
            storeUISupport: storeUISupport
        )
        #endif
    }
}
