import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct StoreRouterTests {
    @Test
    func inactiveStorePathTeardownIsIgnoredWhileActiveNavigationIsAccepted() {
        let router = StoreRouter(path: [.product(7)])
        let activation = NavigationActivation()
        let path = StoreFlowView.navigationPathBinding(
            router: router,
            acceptsUpdates: { activation.value }
        )

        path.wrappedValue = []
        #expect(router.path == [.product(7)])

        activation.value = true
        path.wrappedValue = [.cart]
        #expect(router.path == [.cart])
    }

    @Test
    func inactiveServicesPathTeardownIsIgnoredWhileActiveNavigationIsAccepted() {
        let router = ServicesRouter(path: [.appInfo])
        let activation = NavigationActivation()
        let path = ServicesFlowView.navigationPathBinding(
            router: router,
            acceptsUpdates: { activation.value }
        )

        path.wrappedValue = []
        #expect(router.path == [.appInfo])

        activation.value = true
        path.wrappedValue = [.keychain]
        #expect(router.path == [.keychain])
    }

    @Test
    func requestProtectedExecutesImmediatelyForAuthenticatedSession() {
        let router = StoreRouter(path: [.product(7)])

        let resolution = router.requestProtected(
            .favorite(7),
            session: authenticatedState(userID: 1)
        )

        #expect(resolution == .execute(.favorite(7)))
        #expect(router.path == [.product(7)])
        #expect(router.presentation == nil)
        #expect(router.pendingProtectedAction == nil)
        #expect(router.lastAppliedSessionRevision == nil)
    }

    @Test
    func guestRequestKeepsOnlyNewestPendingActionAndPresentsAuthentication() {
        let router = StoreRouter()

        #expect(
            router.requestProtected(.favorite(7), session: .guest)
                == .presentAuthentication
        )
        #expect(
            router.requestProtected(.openFavorites, session: .guest)
                == .presentAuthentication
        )

        #expect(router.pendingProtectedAction == .openFavorites)
        #expect(router.presentation == .authentication)
        #expect(router.lastAppliedSessionRevision == nil)
    }

    @Test
    func unavailableRequestIsBlockedWithoutResumableAction() {
        let router = StoreRouter()
        _ = router.requestProtected(.favorite(7), session: .guest)

        let resolution = router.requestProtected(
            .openFavorites,
            session: .unavailable(.secureStorageReadFailed)
        )

        #expect(resolution == .blocked(.secureStorageReadFailed))
        #expect(router.pendingProtectedAction == nil)
        #expect(router.presentation == nil)
    }

    @Test(arguments: [
        StorePresentation.filters,
        .checkout,
        .reminder(7)
    ])
    func cancelAuthenticationDoesNotDismissGuestCapablePresentation(
        presentation: StorePresentation
    ) {
        let router = StoreRouter()
        router.presentation = presentation

        router.cancelAuthentication()

        #expect(router.presentation == presentation)
        #expect(router.pendingProtectedAction == nil)
    }

    @Test
    func cancelAuthenticationClearsOnlyPendingActionAndAuthentication() {
        let router = StoreRouter()
        _ = router.requestProtected(.favorite(7), session: .guest)

        router.cancelAuthentication()

        #expect(router.pendingProtectedAction == nil)
        #expect(router.presentation == nil)
    }

    @Test(arguments: [
        ProfileSection.overview,
        .preferences,
        .about
    ])
    func publicProfileSectionSelectsImmediately(section: ProfileSection) {
        let router = StoreRouter()

        #expect(router.selectProfileSection(section, session: .guest) == nil)
        #expect(router.profileSection == section)
        #expect(router.pendingProtectedAction == nil)
    }

    @Test
    func accountSelectionUsesProtectedPolicyWithoutRecursiveAction() {
        let guestRouter = StoreRouter()
        #expect(
            guestRouter.selectProfileSection(.account, session: .guest)
                == .presentAuthentication
        )
        #expect(guestRouter.profileSection == .overview)
        #expect(guestRouter.pendingProtectedAction == .openAccount)

        let authenticatedRouter = StoreRouter()
        #expect(
            authenticatedRouter.selectProfileSection(
                .account,
                session: authenticatedState(userID: 1)
            ) == nil
        )
        #expect(authenticatedRouter.profileSection == .account)
        #expect(authenticatedRouter.pendingProtectedAction == nil)
    }

    @Test
    func resetAccountPresentationSelectsOverviewAndClearsCache() {
        let router = StoreRouter()
        _ = router.selectProfileSection(
            .account,
            session: authenticatedState(userID: 1)
        )
        router.cacheAccountPresentation(account(userID: 1))

        router.resetAccountPresentation()

        #expect(router.profileSection == .overview)
        #expect(router.cachedAccountPresentation == nil)
    }

    @Test
    func restoringRevisionRecordsOnlyRevision() {
        let router = StoreRouter(path: [.profile, .favorites])
        _ = router.requestProtected(.favorite(7), session: .guest)
        router.cacheAccountPresentation(account(userID: 1))

        #expect(
            router.reconcile(.init(state: .restoring, revision: 4)) == nil
        )

        #expect(router.path == [.profile, .favorites])
        #expect(router.presentation == .authentication)
        #expect(router.pendingProtectedAction == .favorite(7))
        #expect(router.cachedAccountPresentation?.userID == 1)
        #expect(router.lastAppliedSessionRevision == 4)
    }

    @Test
    func initialAuthenticatedRevisionNeverConsumesPendingAction() {
        let router = StoreRouter()
        _ = router.requestProtected(.favorite(7), session: .guest)

        #expect(
            router.reconcile(authenticatedPresentation(userID: 1, revision: 1))
                == nil
        )

        #expect(router.pendingProtectedAction == .favorite(7))
        #expect(router.presentation == .authentication)
        #expect(router.lastAppliedSessionRevision == 1)
    }

    @Test
    func duplicateAndOlderRevisionsCannotConsumeOrMutate() {
        let router = StoreRouter(path: [.profile, .favorites])
        _ = router.reconcile(.init(state: .guest, revision: 3))
        _ = router.requestProtected(.favorite(7), session: .guest)

        #expect(
            router.reconcile(authenticatedPresentation(userID: 1, revision: 3))
                == nil
        )
        #expect(
            router.reconcile(authenticatedPresentation(userID: 1, revision: 2))
                == nil
        )

        #expect(router.path == [.profile])
        #expect(router.pendingProtectedAction == .favorite(7))
        #expect(router.presentation == .authentication)
        #expect(router.lastAppliedSessionRevision == 3)
    }

    @Test
    func guestToAuthenticatedTakesAndClearsActionExactlyOnce() {
        let router = StoreRouter()
        _ = router.reconcile(.init(state: .guest, revision: 1))
        _ = router.requestProtected(.favorite(7), session: .guest)

        #expect(
            router.reconcile(authenticatedPresentation(userID: 1, revision: 2))
                == .favorite(7)
        )
        #expect(router.pendingProtectedAction == nil)
        #expect(router.presentation == nil)
        #expect(
            router.reconcile(authenticatedPresentation(userID: 1, revision: 3))
                == nil
        )
    }

    @Test
    func sameUserRevisionDoesNotConsumeAgainOrPrune() {
        let router = StoreRouter(path: [.profile, .favorites, .product(7)])
        _ = router.reconcile(authenticatedPresentation(userID: 1, revision: 2))
        router.cacheAccountPresentation(account(userID: 1))
        router.presentation = .checkout

        #expect(
            router.reconcile(
                authenticatedPresentation(
                    userID: 1,
                    availability: .offline(.transport),
                    revision: 3
                )
            ) == nil
        )

        #expect(router.path == [.profile, .favorites, .product(7)])
        #expect(router.cachedAccountPresentation?.userID == 1)
        #expect(router.presentation == .checkout)
    }

    @Test
    func identityChangePrunesWithoutExecutingStaleAction() {
        let router = StoreRouter(path: [.profile, .favorites])
        _ = router.reconcile(authenticatedPresentation(userID: 1, revision: 1))
        _ = router.requestProtected(.favorite(7), session: .guest)
        _ = router.selectProfileSection(
            .account,
            session: authenticatedState(userID: 1)
        )
        router.cacheAccountPresentation(account(userID: 1))

        #expect(
            router.reconcile(authenticatedPresentation(userID: 2, revision: 2))
                == nil
        )

        #expect(router.path == [.profile])
        #expect(router.pendingProtectedAction == nil)
        #expect(router.presentation == nil)
        #expect(router.profileSection == .overview)
        #expect(router.cachedAccountPresentation == nil)
    }

    @Test(arguments: [
        SessionState.guest,
        .unavailable(.secureStorageCleanupFailed)
    ])
    func nonAuthenticatedRevisionPrunesOnlyProtectedState(
        state: SessionState
    ) {
        let router = StoreRouter(
            path: [
                .favorites,
                .profile,
                .product(7),
                .favorites,
                .reviews(7),
                .cart
            ]
        )
        _ = router.reconcile(authenticatedPresentation(userID: 1, revision: 1))
        _ = router.selectProfileSection(
            .account,
            session: authenticatedState(userID: 1)
        )
        router.cacheAccountPresentation(account(userID: 1))
        router.presentation = .reminder(7)

        #expect(router.reconcile(.init(state: state, revision: 2)) == nil)

        #expect(router.path == [.profile, .product(7), .reviews(7), .cart])
        #expect(router.presentation == .reminder(7))
        #expect(router.pendingProtectedAction == nil)
        #expect(router.profileSection == .overview)
        #expect(router.cachedAccountPresentation == nil)
    }

    @Test
    func resetClearsNavigationButPreservesReconciliationHistory() {
        let router = StoreRouter(path: [.profile, .favorites])
        _ = router.reconcile(authenticatedPresentation(userID: 1, revision: 4))
        _ = router.requestProtected(.favorite(7), session: .guest)
        _ = router.selectProfileSection(
            .account,
            session: authenticatedState(userID: 1)
        )
        router.cacheAccountPresentation(account(userID: 1))

        router.reset()

        #expect(router.path.isEmpty)
        #expect(router.presentation == nil)
        #expect(router.pendingProtectedAction == nil)
        #expect(router.profileSection == .overview)
        #expect(router.cachedAccountPresentation == nil)
        #expect(router.lastAppliedSessionRevision == 4)
        #expect(
            router.reconcile(authenticatedPresentation(userID: 1, revision: 4))
                == nil
        )
        #expect(
            router.reconcile(authenticatedPresentation(userID: 1, revision: 5))
                == nil
        )
    }

    private func authenticatedState(
        userID: Int,
        availability: SessionAvailability = .online
    ) -> SessionState {
        .authenticated(profile(userID: userID), availability: availability)
    }

    private func authenticatedPresentation(
        userID: Int,
        availability: SessionAvailability = .online,
        revision: UInt64
    ) -> SessionPresentation {
        .init(
            state: authenticatedState(
                userID: userID,
                availability: availability
            ),
            revision: revision
        )
    }

    private func profile(userID: Int) -> UserProfile {
        UserProfile(
            id: userID,
            username: "user\(userID)",
            firstName: "User",
            lastName: "\(userID)",
            imageURL: nil
        )
    }

    private func account(userID: Int) -> ProfileAccountPresentation {
        ProfileAccountPresentation(
            userID: userID,
            displayName: "User \(userID)",
            availability: .online
        )
    }
}

@MainActor
private final class NavigationActivation {
    var value = false
}

@MainActor
struct StorePresentationHostPolicyTests {
    @Test
    func macOSSelectsExactlyOneHostForTheActiveNavigationLevel() {
        let route = StoreRoute.product(7)

        #expect(
            StorePresentationHostPolicy.rootIsActive(
                isMacOS: true,
                path: []
            )
        )
        #expect(
            !StorePresentationHostPolicy.routeIsActive(
                isMacOS: true,
                path: [],
                route: route
            )
        )
        #expect(
            !StorePresentationHostPolicy.rootIsActive(
                isMacOS: true,
                path: [route]
            )
        )
        #expect(
            StorePresentationHostPolicy.routeIsActive(
                isMacOS: true,
                path: [route],
                route: route
            )
        )
        #expect(
            !StorePresentationHostPolicy.routeIsActive(
                isMacOS: true,
                path: [route],
                route: .cart
            )
        )
    }

    @Test
    func iOSKeepsTheSingleRootHostActiveAtEveryNavigationLevel() {
        let route = StoreRoute.product(7)

        #expect(
            StorePresentationHostPolicy.rootIsActive(
                isMacOS: false,
                path: [route]
            )
        )
        #expect(
            !StorePresentationHostPolicy.routeIsActive(
                isMacOS: false,
                path: [route],
                route: route
            )
        )
    }

    @Test
    func onlyTheActiveHostReadsAndDismissesThePresentation() {
        let router = StoreRouter()
        router.presentation = .reminder(7)

        #expect(
            StorePresentationHostPolicy.presentation(
                from: router,
                isActive: false
            ) == nil
        )
        StorePresentationHostPolicy.updatePresentation(
            nil,
            on: router,
            isActive: false
        )
        #expect(router.presentation == .reminder(7))
        #expect(
            StorePresentationHostPolicy.presentation(
                from: router,
                isActive: true
            ) == .reminder(7)
        )

        StorePresentationHostPolicy.updatePresentation(
            nil,
            on: router,
            isActive: true
        )

        #expect(router.presentation == nil)
    }
}
