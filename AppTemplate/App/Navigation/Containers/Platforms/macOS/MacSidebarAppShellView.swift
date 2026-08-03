#if os(macOS)
import SwiftUI

struct MacSidebarAppShellView: View {
    @Bindable var router: AppRouter
    let settings: SettingsDependencies

    var body: some View {
        NavigationSplitView {
            List(selection: $router.selectedSection) {
                ForEach(AppSection.allCases) { section in
                    Label(
                        section.localizedTitle,
                        systemImage: section.systemImage
                    )
                    .accessibilityIdentifier(
                        section.accessibilityIdentifier
                    )
                    .tag(section)
                }
            }
            .listStyle(.sidebar)
        } detail: {
            AppSectionContentView(
                section: router.selectedSection,
                router: router,
                settings: settings
            )
        }
    }
}
#endif
