import SwiftUI

struct AuthenticationFlowView: View {
    @Bindable var router: FlowRouter
    let authenticationCancellation: any IAuthenticationCancellation

    var body: some View {
        NavigationStack(path: $router.path) {
            AuthenticationView(
                router: router,
                authenticationCancellation: authenticationCancellation
            )
        }
    }
}
