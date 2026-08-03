#if os(iOS)
import SwiftUI

struct AdaptiveTabAppShellView: View {
    @Bindable var router: AppRouter
    let settings: SettingsDependencies

    var body: some View {
        TabView(selection: $router.selectedSection) {
            ForEach(AppSection.allCases) { section in
                Tab(
                    section.localizedTitle,
                    systemImage: section.systemImage,
                    value: section
                ) {
                    AppSectionContentView(
                        section: section,
                        router: router,
                        settings: settings
                    )
                    .background {
                        TabAccessibilityIdentifierInstaller()
                            .frame(width: 0, height: 0)
                            .accessibilityHidden(true)
                    }
                }
                .customizationID(section.presentationIdentifier)
                .accessibilityIdentifier(
                    section.accessibilityIdentifier
                )
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}
#endif
