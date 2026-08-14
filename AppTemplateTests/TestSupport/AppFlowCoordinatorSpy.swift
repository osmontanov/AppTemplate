import SwiftUI
@testable import AppTemplate

nonisolated
enum AppFlowCoordinatorCommand: Equatable, Sendable {
    case completeOnboarding
    case restartOnboarding
    case setMaintenanceEnabled(Bool)
}

@MainActor
final class AppFlowCoordinatorSpy: IAppFlowCoordinator {
    private(set) var commands: [AppFlowCoordinatorCommand] = []
    var completeOnboardingResult: AppFlowActionResult = .unchanged
    var restartOnboardingResult: AppFlowActionResult = .unchanged
    var setMaintenanceEnabledResult: AppFlowActionResult = .unchanged

    @discardableResult
    func completeOnboarding() -> AppFlowActionResult {
        commands.append(.completeOnboarding)
        return completeOnboardingResult
    }

    @discardableResult
    func restartOnboarding() -> AppFlowActionResult {
        commands.append(.restartOnboarding)
        return restartOnboardingResult
    }

    @discardableResult
    func setMaintenanceEnabled(_ isEnabled: Bool) -> AppFlowActionResult {
        commands.append(.setMaintenanceEnabled(isEnabled))
        return setMaintenanceEnabledResult
    }
}

@MainActor
func makeTestFlowRouter() -> FlowRouter {
    FlowRouter(appFlowCoordinator: AppFlowCoordinatorSpy())
}

@MainActor
func makeTestAppFlowCoordinator(
    state: AppState = .initial,
    isLocalSessionBootstrapResolved: Bool = true,
    visibleFlow: AppFlow? = nil
) -> AppFlowCoordinator {
    let store = AppStateStore(storage: AppStateStorageSpy())
    _ = store.setState(state)
    let appFlowRouter = AppFlowRouter(
        flow: visibleFlow ?? AppFlowPolicy.resolve(
            state,
            isLocalSessionBootstrapResolved: isLocalSessionBootstrapResolved
        )
    )
    return AppFlowCoordinator(
        store: store,
        appFlowRouter: appFlowRouter,
        isLocalSessionBootstrapResolved: isLocalSessionBootstrapResolved
    )
}

@MainActor
protocol LocalOnlyRouterSpy: IFlowRouter {}
