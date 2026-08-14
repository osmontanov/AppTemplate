import Observation

@MainActor
@Observable
final class ProfileViewModel {
    private let appInfo: any IAppInfoService
    private let preferences: any IStorePreferencesRepository
    private(set) var state: ProfileState = .idle
    private(set) var model: ProfileModel?

    init(appInfo: any IAppInfoService, preferences: any IStorePreferencesRepository) {
        self.appInfo = appInfo
        self.preferences = preferences
    }

    func load() async {
        model = ProfileModel(
            displayName: appInfo.displayName,
            version: appInfo.version,
            preferences: await preferences.current()
        )
        state = .loaded
    }
}
