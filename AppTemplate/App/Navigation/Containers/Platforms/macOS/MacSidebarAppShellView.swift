#if os(macOS)
import SwiftUI

struct MacSidebarAppShellView: View {
    @Bindable var router: AppRouter
    let session: SessionPresentation
    let storeDependencies: StoreDependencies
    let storeUISupport: StoreUISupport
    let servicesDependencies: ServicesDependencies
    let sceneNavigation: any ISceneNavigationActions

    var body: some View {
        NavigationSplitView {
            List(selection: $router.selectedSection) {
                ForEach(AppSection.allCases) { section in
                    Label(section.localizedTitle, systemImage: section.systemImage)
                        .accessibilityValue(
                            router.selectedSection == section
                                ? StoreServicesText.resource("Selected")
                                : StoreServicesText.resource("Not selected")
                        )
                        .accessibilityIdentifier(section.accessibilityIdentifier)
                        .tag(section)
                }
            }
            .listStyle(.sidebar)
        } detail: {
            AppSectionContentView(
                section: router.selectedSection,
                storeRouter: router.store,
                servicesRouter: router.services,
                session: session,
                storeDependencies: storeDependencies,
                storeUISupport: storeUISupport,
                servicesDependencies: servicesDependencies,
                sceneNavigation: sceneNavigation
            )
        }
        .frame(minWidth: 820, minHeight: 620)
    }
}
#endif
