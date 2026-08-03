nonisolated
enum UITestRoot: String, Equatable, Sendable {
    case onboarding
    case authentication
    case main
    case maintenance

    var initialState: AppState {
        switch self {
        case .onboarding:
            .initial
        case .authentication:
            AppState(
                isAuthenticated: false,
                hasCompletedOnboarding: true,
                isMaintenanceEnabled: false
            )
        case .main:
            AppState(
                isAuthenticated: true,
                hasCompletedOnboarding: true,
                isMaintenanceEnabled: false
            )
        case .maintenance:
            AppState(
                isAuthenticated: true,
                hasCompletedOnboarding: true,
                isMaintenanceEnabled: true
            )
        }
    }
}

nonisolated
enum AppLaunchConfiguration: Equatable, Sendable {
    case live
    case uiTesting(initialState: AppState)

    var sceneNavigationPersistencePolicy: AppSceneNavigationPersistencePolicy {
        switch self {
        case .live:
            .restored
        case .uiTesting:
            .ephemeral
        }
    }

    init(arguments: [String]) {
        let uiTestingMarker = "--ui-testing"
        let uiTestRootOption = "--ui-test-root"

        guard arguments.count == 4,
              arguments[1] == uiTestingMarker,
              arguments[2] == uiTestRootOption,
              let root = UITestRoot(rawValue: arguments[3])
        else {
            self = .live
            return
        }

        self = .uiTesting(initialState: root.initialState)
    }
}
