import SwiftUI

struct AppSettingsView: View {
    @State private var viewModel: AppSettingsViewModel

    init(dependencies: SettingsDependencies) {
        _viewModel = State(
            initialValue: AppSettingsViewModel(
                appInfo: dependencies.appInfo
            )
        )
    }

    var body: some View {
        Form {
            Section("App") {
                LabeledContent {
                    Text(verbatim: viewModel.model.displayName)
                } label: {
                    Text("Name")
                }
                LabeledContent {
                    Text(verbatim: viewModel.model.version)
                } label: {
                    Text("Version")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 180)
        .scenePadding()
    }
}
