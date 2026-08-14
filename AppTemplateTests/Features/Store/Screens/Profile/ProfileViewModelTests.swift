import Testing
@testable import AppTemplate

@MainActor
struct ProfileViewModelTests {
    @Test
    func profileCombinesPublicAppInfoAndSharedPreferences() async {
        let preferences = ControlledStorePreferencesRepository(StorePreferences(layout: .list, sort: .featured, preferredRemotePageSize: 50))
        let viewModel = ProfileViewModel(
            appInfo: AppInfoService(displayName: "Mini Store", version: "2.0"),
            preferences: preferences
        )

        await viewModel.load()

        #expect(viewModel.model == ProfileModel(displayName: "Mini Store", version: "2.0", preferences: StorePreferences(layout: .list, sort: .featured, preferredRemotePageSize: 50)))
    }
}
