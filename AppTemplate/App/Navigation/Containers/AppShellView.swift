import SwiftUI

struct AppShellView: View {
    @Bindable var router: AppRouter
    let settings: SettingsDependencies

    var body: some View {
#if os(macOS)
        MacSidebarAppShellView(
            router: router,
            settings: settings
        )
#else
        AdaptiveTabAppShellView(
            router: router,
            settings: settings
        )
#endif
    }
}
