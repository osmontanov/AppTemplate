import Testing
@testable import AppTemplate

@MainActor
struct SessionInfoViewModelTests {
    @Test
    func sessionInfoViewModelAndScreenNeedNoDependencies() {
        _ = SessionInfoViewModel()
        _ = SessionInfoView()
    }
}
