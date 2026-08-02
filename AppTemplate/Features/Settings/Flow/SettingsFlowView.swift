import SwiftUI

struct SettingsFlowView: View {
    @Bindable var router: FlowRouter
    let dependencies: SettingsDependencies

    var body: some View {
        NavigationStack(path: $router.path) {
            SettingsView(
                router: router,
                dependencies: dependencies
            )
        }
    }
}

#Preview("Settings") {
    PreviewFixtures.settingsFlow()
}
