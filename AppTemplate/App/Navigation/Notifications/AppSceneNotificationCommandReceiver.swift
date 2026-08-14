import Foundation

@MainActor
final class AppSceneNotificationCommandReceiver: LocalNotificationSceneReceiving {
    private let navigation: AppSceneNavigationLifecycle
    private let router: StoreRouter
    private let executor: ProtectedStoreActionExecutor
    private let session: any ISessionActions

    init(
        navigation: AppSceneNavigationLifecycle,
        router: StoreRouter,
        executor: ProtectedStoreActionExecutor,
        session: any ISessionActions
    ) {
        self.navigation = navigation
        self.router = router
        self.executor = executor
        self.session = session
    }

    func receiveNotificationCommand(_ command: NotificationNavigationCommand) async {
        switch command {
        case let .navigate(intent):
            navigation.handleSampleIntent(intent)
        case let .protected(action):
            let state = session.presentation.state
            guard case .restoring = state else {
                switch router.requestProtected(action, session: state) {
                case let .execute(resolved):
                    guard case let .authenticated(profile, _) = state else { return }
                    await executor.execute(resolved, expectedUserID: profile.id)
                case .presentAuthentication:
                    break
                case let .blocked(reason):
                    router.presentation = .sessionRecovery(reason)
                }
                return
            }
        }
    }
}
