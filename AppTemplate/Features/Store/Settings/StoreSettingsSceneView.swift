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
        .frame(minWidth: 360, idealWidth: 440, minHeight: 360)
        .scenePadding()
        .accessibilityIdentifier(AppAccessibilityIdentifier.screen(.storePreferences))
    }
}
