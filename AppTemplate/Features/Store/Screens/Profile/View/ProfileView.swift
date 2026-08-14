import SwiftUI

struct ProfileView: View {
    let preferences: any IStorePreferencesRepository
    @State private var viewModel: ProfileViewModel

    init(appInfo: any IAppInfoService, preferences: any IStorePreferencesRepository) {
        self.preferences = preferences
        _viewModel = State(initialValue: ProfileViewModel(appInfo: appInfo, preferences: preferences))
    }

    var body: some View {
        Form {
            if let model = viewModel.model {
                Section("About") {
                    LabeledContent("Name", value: model.displayName)
                    LabeledContent("Version", value: model.version)
                    Text("You are browsing as a guest.").foregroundStyle(.secondary)
                }
            }
            Section("Store preferences") {
                StorePreferencesForm(repository: preferences)
            }
        }
        .navigationTitle("Profile")
        .task { await viewModel.load() }
        .accessibilityIdentifier("screen.store.profile")
    }
}
