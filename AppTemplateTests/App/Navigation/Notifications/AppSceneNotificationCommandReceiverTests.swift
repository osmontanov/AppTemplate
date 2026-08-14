import Foundation
import Testing
@testable import AppTemplate

@MainActor
struct AppSceneNotificationCommandReceiverTests {
    @Test
    func navigateUsesLifecycleTypedNavigationPath() async {
        let fixture = makeFixture(state: .guest)

        await fixture.receiver.receiveNotificationCommand(
            .navigate(.openProduct(12))
        )

        #expect(fixture.lifecycle.router.store.path == [.product(12)])
    }

    @Test
    func authenticatedFavoriteExecutesThroughProtectedExecutorOnce() async throws {
        let fixture = makeFixture(state: .authenticated(.receiverUser(7), availability: .online))

        await fixture.receiver.receiveNotificationCommand(.protected(.favorite(12)))

        #expect(try await fixture.favorites.contains(userID: 7, productID: 12))
        #expect(await fixture.products.requestedProductIDs == [12])
    }

    @Test
    func guestFavoriteUsesOneRouterPendingActionThenNormalLoginReconciliation() async throws {
        let fixture = makeFixture(state: .guest)
        await fixture.receiver.receiveNotificationCommand(.protected(.favorite(12)))

        #expect(fixture.lifecycle.router.store.pendingProtectedAction == .favorite(12))
        #expect(fixture.lifecycle.router.store.presentation == .authentication)
        #expect(!(try await fixture.favorites.contains(userID: 7, productID: 12)))

        fixture.session.presentation = .init(
            state: .authenticated(.receiverUser(7), availability: .online),
            revision: 2
        )
        fixture.executor.sessionDidChange(fixture.session.presentation)
        let pending = fixture.lifecycle.reconcile(fixture.session.presentation)
        if let pending {
            await fixture.executor.execute(pending, expectedUserID: 7)
        }
        _ = fixture.lifecycle.reconcile(fixture.session.presentation)

        #expect(try await fixture.favorites.contains(userID: 7, productID: 12))
        #expect(await fixture.products.requestedProductIDs == [12])
        #expect(fixture.lifecycle.router.store.pendingProtectedAction == nil)
    }

    @Test
    func unavailableSessionShowsRecoveryWithoutFavoriteOrNavigationMutation() async throws {
        let fixture = makeFixture(state: .unavailable(.secureStorageReadFailed))

        await fixture.receiver.receiveNotificationCommand(.protected(.favorite(12)))

        #expect(
            fixture.lifecycle.router.store.presentation
                == .sessionRecovery(.secureStorageReadFailed)
        )
        #expect(fixture.lifecycle.router.store.path.isEmpty)
        #expect(!(try await fixture.favorites.contains(userID: 7, productID: 12)))
        #expect(await fixture.products.requestedProductIDs.isEmpty)
    }
}

@MainActor
private extension AppSceneNotificationCommandReceiverTests {
    struct Fixture {
        let lifecycle: AppSceneNavigationLifecycle
        let executor: ProtectedStoreActionExecutor
        let receiver: AppSceneNotificationCommandReceiver
        let session: ReceiverSessionActions
        let products: ControlledProductRepository
        let favorites: FavoritesRepository
    }

    func makeFixture(state: SessionState) -> Fixture {
        let session = ReceiverSessionActions(state: state)
        let lifecycle = AppSceneNavigationLifecycle(router: AppRouter(
            appFlowRouter: AppFlowRouter(flow: .main)
        ))
        _ = lifecycle.restore(from: nil)
        _ = lifecycle.reconcile(session.presentation)
        let products = ControlledProductRepository(products: [.fixture(id: 12)])
        let database = LocalDatabaseService(configuration: .inMemory())
        let favorites = FavoritesRepository(database: database)
        let executor = ProtectedStoreActionExecutor(
            router: lifecycle.router.store,
            products: products,
            favorites: favorites,
            session: session
        )
        return Fixture(
            lifecycle: lifecycle,
            executor: executor,
            receiver: AppSceneNotificationCommandReceiver(
                navigation: lifecycle,
                router: lifecycle.router.store,
                executor: executor,
                session: session
            ),
            session: session,
            products: products,
            favorites: favorites
        )
    }
}

@MainActor
private final class ReceiverSessionActions: ISessionActions {
    var presentation: SessionPresentation
    var status: SessionStatusPresentation { .init(session: presentation, expiry: nil) }

    init(state: SessionState) {
        presentation = SessionPresentation(state: state, revision: 1)
    }

    func bootstrap() async {}
    func retryBootstrap() async {}
    func login(username: String, password: String) async -> SessionLoginResult {
        _ = username
        _ = password
        return .cancelled
    }
    func retryPersistence(
        _ token: SessionPersistenceRetryToken
    ) async -> SessionPersistenceRetryResult {
        _ = token
        return .cancelled
    }
    func discardPersistenceRetry(_ token: SessionPersistenceRetryToken) async {
        _ = token
    }
    func validateSession() async -> SessionValidationResult { .unchanged }
    func refreshSession() async -> SessionValidationResult { .unchanged }
    func signOut() async -> SessionSignOutResult { .cancelled }
}

private extension UserProfile {
    static func receiverUser(_ id: Int) -> UserProfile {
        UserProfile(
            id: id,
            username: "user\(id)",
            firstName: "User",
            lastName: "\(id)",
            imageURL: nil
        )
    }
}
