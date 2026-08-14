import Testing
@testable import AppTemplate

struct AppFlowPolicyTests {
    @Test func rootPriorityIsExact() {
        #expect(AppFlowPolicy.resolve(
            .init(hasCompletedOnboarding: true, isMaintenanceEnabled: true),
            isLocalSessionBootstrapResolved: false
        ) == .maintenance)
        #expect(AppFlowPolicy.resolve(
            .init(hasCompletedOnboarding: false, isMaintenanceEnabled: true),
            isLocalSessionBootstrapResolved: false
        ) == .maintenance)
        #expect(AppFlowPolicy.resolve(
            .init(hasCompletedOnboarding: false, isMaintenanceEnabled: false),
            isLocalSessionBootstrapResolved: true
        ) == .onboarding)
        #expect(AppFlowPolicy.resolve(
            .init(hasCompletedOnboarding: true, isMaintenanceEnabled: false),
            isLocalSessionBootstrapResolved: false
        ) == .restoring)
        #expect(AppFlowPolicy.resolve(
            .init(hasCompletedOnboarding: true, isMaintenanceEnabled: false),
            isLocalSessionBootstrapResolved: true
        ) == .main)
    }
}
