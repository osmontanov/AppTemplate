import SwiftUI
@testable import AppTemplate

nonisolated
enum AppFlowCoordinatorCommand: Equatable, Sendable {
    case setFlow(AppFlow)
    case completeOnboarding
    case restartOnboarding
    case signIn
    case signOut
    case setMaintenanceEnabled(Bool)
}

@MainActor
final class AppFlowCoordinatorSpy: IAppFlowCoordinator {
    private(set) var commands: [AppFlowCoordinatorCommand] = []

    func setFlow(_ flow: AppFlow) {
        commands.append(.setFlow(flow))
    }

    func completeOnboarding() {
        commands.append(.completeOnboarding)
    }

    func restartOnboarding() {
        commands.append(.restartOnboarding)
    }

    func signIn() {
        commands.append(.signIn)
    }

    func signOut() {
        commands.append(.signOut)
    }

    func setMaintenanceEnabled(_ isEnabled: Bool) {
        commands.append(.setMaintenanceEnabled(isEnabled))
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
protocol LocalOnlyRouterSpy: IRouter {}

extension LocalOnlyRouterSpy {
    func setFlow(_ flow: AppFlow) {}
    func completeOnboarding() {}
    func restartOnboarding() {}
    func signIn() {}
    func signOut() {}
    func setMaintenanceEnabled(_ isEnabled: Bool) {}
}
