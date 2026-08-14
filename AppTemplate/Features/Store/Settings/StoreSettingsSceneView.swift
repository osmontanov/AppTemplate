import SwiftUI

struct StoreSettingsSceneView: View {
    let dependencies: StoreDependencies

    var body: some View {
        Form {
            Section("App") {
                LabeledContent("Name", value: dependencies.appInfo.displayName)
                LabeledContent("Version", value: dependencies.appInfo.version)
            }
            Section("Store") {
                StorePreferencesForm(repository: dependencies.preferences)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 360)
        .scenePadding()
        .accessibilityIdentifier("screen.store.settings")
    }
}
