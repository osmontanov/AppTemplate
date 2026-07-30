import SwiftUI

struct AuthenticationFlowView: View {
    @Bindable var router: FlowRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            AuthenticationView(router: router)
        }
    }
}
