import SwiftUI

struct SettingsFlowView: View {
    @Bindable var router: FlowRouter
    let sessionStore: SessionStore

    var body: some View {
        NavigationStack(path: $router.path) {
            SettingsView(
                router: router,
                sessionStore: sessionStore
            )
        }
    }
}
