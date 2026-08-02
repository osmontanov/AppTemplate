import Observation

@MainActor
@Observable
final class AppSettingsViewModel {
    let model: AppSettingsModel

    init(appInfo: any IAppInfoService) {
        model = AppSettingsModel(
            displayName: appInfo.displayName,
            version: appInfo.version
        )
    }
}
