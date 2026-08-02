import Testing
@testable import AppTemplate

struct AppLaunchConfigurationTests {
    @Test(arguments: [
        (
            "onboarding",
            AppState(
                isAuthenticated: false,
                hasCompletedOnboarding: false,
                isMaintenanceEnabled: false
            )
        ),
        (
            "authentication",
            AppState(
                isAuthenticated: false,
                hasCompletedOnboarding: true,
                isMaintenanceEnabled: false
            )
        ),
        (
            "main",
            AppState(
                isAuthenticated: true,
                hasCompletedOnboarding: true,
                isMaintenanceEnabled: false
            )
        ),
        (
            "maintenance",
            AppState(
                isAuthenticated: true,
                hasCompletedOnboarding: true,
                isMaintenanceEnabled: true
            )
        )
    ])
    func explicitUITestRootMapsToState(root: String, expected: AppState) {
        #expect(
            AppLaunchConfiguration(
                arguments: ["AppTemplate", "--ui-testing", "--ui-test-root", root]
            ) == .uiTesting(initialState: expected)
        )
    }

    @Test(arguments: [
        ["AppTemplate", "--ui-test-root", "main"],
        ["AppTemplate", "--ui-testing"],
        ["AppTemplate", "--ui-testing", "--ui-test-root"],
        ["AppTemplate", "--ui-testing", "--ui-test-root", "unknown"],
        [
            "AppTemplate", "--ui-testing", "--ui-test-root", "main",
            "--ui-test-root", "maintenance"
        ],
        [
            "AppTemplate", "--ui-testing", "--ui-testing", "--ui-test-root", "main"
        ]
    ])
    func malformedUITestArgumentsRemainLive(arguments: [String]) {
        #expect(AppLaunchConfiguration(arguments: arguments) == .live)
    }
}
