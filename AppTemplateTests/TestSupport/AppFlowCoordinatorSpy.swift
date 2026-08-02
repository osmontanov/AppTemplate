import SwiftUI
@testable import AppTemplate

nonisolated
enum AppFlowCoordinatorCommand: Equatable, Sendable {
    case completeOnboarding
    case restartOnboarding
    case signIn
    case signOut
    case setMaintenanceEnabled(Bool)
}

@MainActor
final class AppFlowCoordinatorSpy: IAppFlowCoordinator {
    private(set) var commands: [AppFlowCoordinatorCommand] = []
    var completeOnboardingResult: AppFlowActionResult = .unchanged
    var restartOnboardingResult: AppFlowActionResult = .unchanged
    var signInResult: AppFlowActionResult = .unchanged
    var signOutResult: AppFlowActionResult = .unchanged
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
    func signIn() -> AppFlowActionResult {
        commands.append(.signIn)
        return signInResult
    }

    @discardableResult
    func signOut() -> AppFlowActionResult {
        commands.append(.signOut)
        return signOutResult
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
    visibleFlow: AppFlow? = nil
) -> AppFlowCoordinator {
    let store = AppStateStore(storage: AppStateStorageSpy())
    _ = store.setState(state)
    let appFlowRouter = AppFlowRouter(
        flow: visibleFlow ?? AppFlowPolicy.resolve(state)
    )
    return AppFlowCoordinator(
        store: store,
        appFlowRouter: appFlowRouter
    )
}

@MainActor
protocol LocalOnlyRouterSpy: IFlowRouter {}
