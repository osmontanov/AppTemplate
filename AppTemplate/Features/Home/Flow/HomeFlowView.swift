import SwiftUI

struct HomeFlowView: View {
    @Bindable var router: FlowRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            HomeView(router: router)
        }
    }
}

#Preview("Home") {
    PreviewFixtures.homeFlow()
}
