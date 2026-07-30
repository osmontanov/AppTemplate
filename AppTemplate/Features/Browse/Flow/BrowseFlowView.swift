import SwiftUI

struct BrowseFlowView: View {
    @Bindable var router: FlowRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            BrowseView(router: router)
        }
    }
}
