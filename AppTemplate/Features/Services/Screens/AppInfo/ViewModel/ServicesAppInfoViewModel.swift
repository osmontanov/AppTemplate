import Observation

@MainActor
@Observable
final class ServicesAppInfoViewModel {
    let displayName: String
    let version: String
    let platformName: String

    init(appInfo: any IAppInfoService, platformName: String) {
        displayName = appInfo.displayName
        version = appInfo.version
        self.platformName = platformName
    }
}
