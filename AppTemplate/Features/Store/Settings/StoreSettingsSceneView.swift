import SwiftUI

struct StoreSettingsSceneView: View {
    let dependencies: StoreDependencies

    var body: some View {
        Form {
            Section(StoreServicesText.resource("App")) {
                LabeledContent(StoreServicesText.resource("Name"), value: dependencies.appInfo.displayName)
                LabeledContent(StoreServicesText.resource("Version"), value: dependencies.appInfo.version)
            }
            Section(StoreServicesText.resource("Store")) {
                StorePreferencesForm(repository: dependencies.preferences)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 360)
        .scenePadding()
        .accessibilityIdentifier("screen.store.settings")
    }
}
