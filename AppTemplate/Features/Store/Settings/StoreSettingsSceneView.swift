import SwiftUI

struct StoreSettingsSceneView: View {
    let dependencies: StoreDependencies

    var body: some View {
        Form {
            Section(AppText.resource("App")) {
                LabeledContent(AppText.resource("Name"), value: dependencies.appInfo.displayName)
                LabeledContent(AppText.resource("Version"), value: dependencies.appInfo.version)
            }
            Section(AppText.resource("Store")) {
                StorePreferencesForm(repository: dependencies.preferences)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 360, idealWidth: 440, minHeight: 360)
        .scenePadding()
        .accessibilityIdentifier(AppAccessibilityIdentifier.screen(.storePreferences))
    }
}
