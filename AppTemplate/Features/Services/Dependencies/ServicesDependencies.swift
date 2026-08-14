@MainActor
struct ServicesDependencies {
    let appState: any IAppStateInspecting
    let appFlowCoordinator: any IAppFlowCoordinator
    let appStateStatus: ServicesAppStateStatus
    let sessionActions: any ISessionActions
    let appInfo: any IAppInfoService
    let userDefaultsLab: any IUserDefaultsService
    let keychainLab: any IKeychainService
}
