@MainActor
struct ServicesDependencies {
    let appState: any IAppStateInspecting
    let appFlowCoordinator: any IAppFlowCoordinator
    let appStateStatus: ServicesAppStateStatus
    let sessionActions: any ISessionActions
    let appInfo: any IAppInfoService
    let userDefaultsLab: any IUserDefaultsService
    let keychainLab: any IKeychainService
    let localDatabase: any ILocalDatabaseExampleRepository
    let remoteAPI: any IRemoteAPILabService
    let diagnostics: NetworkDiagnosticRecorder
    let notificationLab: any ILocalNotificationLabService
    let notificationAppWide: any ILocalNotificationAppWideCapabilities
    let notificationHistory: any ILocalNotificationEventReading
    let notificationAssets: LocalNotificationLabAssetProvider
}
