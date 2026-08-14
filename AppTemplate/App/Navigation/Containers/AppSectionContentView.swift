import SwiftUI

struct AppSectionContentView: View {
    let section: AppSection
    let storeRouter: StoreRouter
    let servicesRouter: ServicesRouter
    let session: SessionPresentation
    let storeDependencies: StoreDependencies
    let storeUISupport: StoreUISupport

    var body: some View {
        switch section {
        case .store:
            StoreFlowView(
                router: storeRouter,
                dependencies: storeDependencies,
                uiSupport: storeUISupport
            )
        case .services:
            ServicesFlowView(router: servicesRouter, session: session)
        }
    }
}
