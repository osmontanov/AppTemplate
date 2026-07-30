import SwiftUI

struct SettingsFlowView: View {
    @Bindable var router: FlowRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            SettingsView(router: router)
        }
    }
}
