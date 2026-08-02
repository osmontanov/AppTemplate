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

    init(arguments: [String]) {
        let uiTestingMarker = "--ui-testing"
        let uiTestRootOption = "--ui-test-root"

        guard arguments.filter({ $0 == uiTestingMarker }).count == 1,
              arguments.filter({ $0 == uiTestRootOption }).count == 1,
              let rootOptionIndex = arguments.firstIndex(of: uiTestRootOption),
              arguments.indices.contains(rootOptionIndex + 1),
              let root = UITestRoot(rawValue: arguments[rootOptionIndex + 1])
        else {
            self = .live
            return
        }

        self = .uiTesting(initialState: root.initialState)
    }
}
