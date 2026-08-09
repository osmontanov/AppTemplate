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
        var uiTestingArguments = Array(arguments.dropFirst())

        #if os(macOS)
        let persistenceIsolationArguments = [
            "-ApplePersistenceIgnoreState",
            "YES"
        ]
        if uiTestingArguments.count == 5,
           Array(uiTestingArguments.prefix(2)) == persistenceIsolationArguments {
            uiTestingArguments.removeFirst(2)
        }
        #endif

        guard uiTestingArguments.count == 3,
              uiTestingArguments[0] == uiTestingMarker,
              uiTestingArguments[1] == uiTestRootOption,
              let root = UITestRoot(rawValue: uiTestingArguments[2])
        else {
            self = .live
            return
        }

        self = .uiTesting(initialState: root.initialState)
    }
}
