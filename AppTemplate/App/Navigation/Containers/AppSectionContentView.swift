import SwiftUI

struct AppSectionContentView: View {
    let section: AppSection
    let storeRouter: StoreRouter
    let servicesRouter: ServicesRouter
    let session: SessionPresentation

    var body: some View {
        switch section {
        case .store:
            StoreFlowView(router: storeRouter, session: session)
        case .services:
            ServicesFlowView(router: servicesRouter, session: session)
        }
    }
}
