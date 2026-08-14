#if os(iOS)
import SwiftUI

struct AdaptiveTabAppShellView: View {
    @Bindable var router: AppRouter
    let session: SessionPresentation

    var body: some View {
        TabView(selection: $router.selectedSection) {
            ForEach(AppSection.allCases) { section in
                Tab(section.localizedTitle, systemImage: section.systemImage, value: section) {
                    AppSectionContentView(
                        section: section,
                        storeRouter: router.store,
                        servicesRouter: router.services,
                        session: session
                    )
                    .background {
                        TabAccessibilityIdentifierInstaller()
                            .frame(width: 0, height: 0)
                            .accessibilityHidden(true)
                    }
                }
                .customizationID(section.presentationIdentifier)
                .accessibilityIdentifier(section.accessibilityIdentifier)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}
#endif
