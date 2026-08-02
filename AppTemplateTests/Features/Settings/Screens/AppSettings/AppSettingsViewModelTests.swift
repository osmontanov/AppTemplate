import Testing
@testable import AppTemplate

@MainActor
struct AppSettingsViewModelTests {
    @Test
    func appSettingsModelUsesInjectedAppMetadata() {
        let primaryViewModel = AppSettingsViewModel(
            appInfo: AppInfoService(
                displayName: "Preview App",
                version: "9.8.7"
            )
        )
        let alternateViewModel = AppSettingsViewModel(
            appInfo: AppInfoService(
                displayName: "Alternate App",
                version: "2.4.6"
            )
        )

        #expect(
            primaryViewModel.model
                == AppSettingsModel(
                    displayName: "Preview App",
                    version: "9.8.7"
                )
        )
        #expect(
            alternateViewModel.model
                == AppSettingsModel(
                    displayName: "Alternate App",
                    version: "2.4.6"
                )
        )
    }
}
