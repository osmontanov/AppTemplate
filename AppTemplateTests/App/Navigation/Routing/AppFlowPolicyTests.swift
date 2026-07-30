import Testing
@testable import AppTemplate

struct AppFlowPolicyTests {
    @Test(arguments: [
        FlowCase(false, false, false, .onboarding),
        FlowCase(false, false, true, .onboarding),
        FlowCase(false, true, false, .onboarding),
        FlowCase(false, true, true, .onboarding),
        FlowCase(true, false, false, .authentication),
        FlowCase(true, false, true, .authentication),
        FlowCase(true, true, false, .main),
        FlowCase(true, true, true, .maintenance)
    ])
    fileprivate func resolvesTheCompletePriorityTable(testCase: FlowCase) {
        let state = AppState(
            isAuthenticated: testCase.isAuthenticated,
            hasCompletedOnboarding: testCase.hasCompletedOnboarding,
            isMaintenanceEnabled: testCase.isMaintenanceEnabled
        )

        #expect(AppFlowPolicy.resolve(state) == testCase.expectedFlow)
    }
}

nonisolated
private struct FlowCase: Sendable {
    let hasCompletedOnboarding: Bool
    let isAuthenticated: Bool
    let isMaintenanceEnabled: Bool
    let expectedFlow: AppFlow

    init(
        _ hasCompletedOnboarding: Bool,
        _ isAuthenticated: Bool,
        _ isMaintenanceEnabled: Bool,
        _ expectedFlow: AppFlow
    ) {
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.isAuthenticated = isAuthenticated
        self.isMaintenanceEnabled = isMaintenanceEnabled
        self.expectedFlow = expectedFlow
    }
}
