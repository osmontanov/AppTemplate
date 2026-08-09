import Testing
@testable import AppTemplate

struct AppLaunchConfigurationTests {
    @Test
    func launchModeSelectsSceneNavigationPersistence() {
        #expect(
            AppLaunchConfiguration.live.sceneNavigationPersistencePolicy
                == .restored
        )
        #expect(
            AppLaunchConfiguration.uiTesting(initialState: .initial)
                .sceneNavigationPersistencePolicy == .ephemeral
        )
    }

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

    #if os(macOS)
    @Test(arguments: [
        "onboarding",
        "authentication",
        "main",
        "maintenance"
    ])
    func persistenceIsolatedUITestRootMapsToState(_ root: String) throws {
        let uiTestRoot = try #require(UITestRoot(rawValue: root))

        #expect(
            AppLaunchConfiguration(arguments: [
                "AppTemplate",
                "-ApplePersistenceIgnoreState", "YES",
                "--ui-testing", "--ui-test-root", root
            ]) == .uiTesting(initialState: uiTestRoot.initialState)
        )
    }
    #endif

    @Test(arguments: [
        ["AppTemplate", "--ui-test-root", "main"],
        ["AppTemplate", "--ui-testing"],
        ["AppTemplate", "--ui-testing", "--ui-test-root"],
        ["AppTemplate", "--ui-testing", "--ui-test-root", "unknown"],
        ["AppTemplate", "--ui-test-root", "main", "--ui-testing"],
        ["AppTemplate", "--ui-testing", "extra", "--ui-test-root", "main"],
        ["AppTemplate", "--ui-testing", "--ui-test-root", "main", "extra"],
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

    #if os(macOS)
    @Test(arguments: [
        [
            "AppTemplate",
            "-ApplePersistenceIgnoreState", "NO",
            "--ui-testing", "--ui-test-root", "main"
        ],
        [
            "AppTemplate",
            "-ApplePersistenceIgnoreState",
            "--ui-testing", "--ui-test-root", "main"
        ],
        [
            "AppTemplate",
            "--ui-testing", "--ui-test-root", "main",
            "-ApplePersistenceIgnoreState", "YES"
        ],
        [
            "AppTemplate",
            "-ApplePersistenceIgnoreState", "YES",
            "-ApplePersistenceIgnoreState", "YES",
            "--ui-testing", "--ui-test-root", "main"
        ],
        [
            "AppTemplate",
            "-ApplePersistenceIgnoreState", "YES",
            "--unexpected",
            "--ui-testing", "--ui-test-root", "main"
        ],
        [
            "AppTemplate",
            "-ApplePersistenceIgnoreState", "YES",
            "--ui-testing", "--ui-test-root", "unknown"
        ]
    ])
    func malformedPersistenceIsolationArgumentsRemainLive(
        _ arguments: [String]
    ) {
        #expect(AppLaunchConfiguration(arguments: arguments) == .live)
    }
    #endif
}
