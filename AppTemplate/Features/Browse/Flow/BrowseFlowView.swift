import SwiftUI

struct BrowseFlowView: View {
    @Bindable var router: FlowRouter
    let dependencies: BrowseDependencies

    var body: some View {
        NavigationStack(path: $router.path) {
            BrowseView(
                router: router,
                dependencies: dependencies
            )
        }
    }
}
