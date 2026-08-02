import Testing
@testable import AppTemplate

struct AppInfoServiceTests {
    @Test
    func fixedInitializerPreservesAppMetadata() {
        let service = AppInfoService(
            displayName: "Preview App",
            version: "9.8.7"
        )

        #expect(service.displayName == "Preview App")
        #expect(service.version == "9.8.7")
    }
}
