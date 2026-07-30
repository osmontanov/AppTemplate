import SwiftUI

struct AuthenticationFlowView: View {
    @Bindable var router: FlowRouter
    let sessionStore: SessionStore

    var body: some View {
        NavigationStack(path: $router.path) {
            AuthenticationView(
                sessionStore: sessionStore,
                router: router
            )
        }
    }
}
