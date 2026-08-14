import SwiftUI

struct AppShellView: View {
    @Bindable var router: AppRouter
    let session: SessionPresentation

    var body: some View {
        #if os(macOS)
        MacSidebarAppShellView(router: router, session: session)
        #else
        AdaptiveTabAppShellView(router: router, session: session)
        #endif
    }
}
