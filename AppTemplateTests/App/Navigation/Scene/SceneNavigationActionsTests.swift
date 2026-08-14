import Foundation
import Testing
@testable import AppTemplate

@MainActor
struct SceneNavigationActionsTests {
    @Test
    func presentationIsAtomicTypedAndPhaseFourHasNoProtectedPendingAction() {
        let flow = AppFlowRouter(flow: .main)
        let lifecycle = AppSceneNavigationLifecycle(
            router: AppRouter(
                appFlowRouter: flow,
                selectedSection: .services,
                store: StoreRouter(path: [.product(3)]),
                services: ServicesRouter(path: [.keychain])
            )
        )
        _ = lifecycle.restore(from: nil)

        let presentation = lifecycle.presentation()
        #expect(presentation.selectedSection == .services)
        #expect(presentation.storePath == [.product(3)])
        #expect(presentation.servicesPath == [.keychain])
        #expect(presentation.restorationResult == .noState)
        #expect(presentation.checkpoint == flow.transition.id)
        #expect(!presentation.hasDeferredLink)
        #expect(!presentation.hasPendingProtectedAction)
        #expect(presentation.deepLinkFailure == nil)
    }

    @Test
    func resetTouchesOnlyCurrentScene() {
        let first = restoredLifecycle(storePath: [.product(1)])
        let second = restoredLifecycle(storePath: [.product(2)])

        first.resetNavigationInCurrentScene()

        #expect(first.presentation().selectedSection == .store)
        #expect(first.presentation().storePath.isEmpty)
        #expect(first.presentation().servicesPath.isEmpty)
        #expect(second.presentation().storePath == [.product(2)])
    }

    @Test(arguments: [
        (DeepLinkRecoveryAction.openStore, AppSection.store),
        (.openServices, AppSection.services)
    ])
    func rejectedLinkRecoveryIsExplicitAndSceneLocal(
        action: DeepLinkRecoveryAction,
        expectedSection: AppSection
    ) throws {
        let first = restoredLifecycle(
            selectedSection: .services,
            storePath: [.product(1)],
            servicesPath: [.appInfo]
        )
        let second = restoredLifecycle(
            selectedSection: .services,
            storePath: [.product(2)],
            servicesPath: [.keychain]
        )
        _ = first.receive(
            try #require(URL(string: "apptemplate://legacy/private"))
        )

        first.recoverRejectedLink(action)

        #expect(first.presentation().selectedSection == expectedSection)
        #expect(first.presentation().deepLinkFailure == nil)
        switch action {
        case .openStore:
            #expect(first.presentation().storePath.isEmpty)
            #expect(first.presentation().servicesPath == [.appInfo])
        case .openServices:
            #expect(first.presentation().storePath == [.product(1)])
            #expect(first.presentation().servicesPath.isEmpty)
        }
        #expect(second.presentation().storePath == [.product(2)])
        #expect(second.presentation().servicesPath == [.keychain])
    }

    @Test
    func sampleIntentsUseTheSameReplacementPathAsLinks() throws {
        let samples = restoredLifecycle(storePath: [.cart, .profile])
        let links = restoredLifecycle(storePath: [.cart, .profile])

        samples.handleSampleIntent(.openProduct(17))
        _ = links.receive(
            try #require(URL(string: "apptemplate://store/product/17"))
        )

        #expect(
            samples.presentation().selectedSection
                == links.presentation().selectedSection
        )
        #expect(
            samples.presentation().storePath
                == links.presentation().storePath
        )
        #expect(
            samples.presentation().servicesPath
                == links.presentation().servicesPath
        )
    }

    @Test
    func resetClearsDeferredLinkAndRejectedLinkPresentation() throws {
        let lifecycle = AppSceneNavigationLifecycle(
            router: AppRouter(appFlowRouter: AppFlowRouter(flow: .restoring))
        )
        _ = lifecycle.receive(
            try #require(URL(string: "apptemplate://store/product/4"))
        )
        _ = lifecycle.receive(
            try #require(URL(string: "apptemplate://legacy/private"))
        )

        lifecycle.resetNavigationInCurrentScene()

        #expect(!lifecycle.presentation().hasDeferredLink)
        #expect(lifecycle.presentation().deepLinkFailure == nil)
    }

    private func restoredLifecycle(
        selectedSection: AppSection = .store,
        storePath: [StoreRoute] = [],
        servicesPath: [ServicesRoute] = []
    ) -> AppSceneNavigationLifecycle {
        let lifecycle = AppSceneNavigationLifecycle(
            router: AppRouter(
                appFlowRouter: AppFlowRouter(flow: .main),
                selectedSection: selectedSection,
                store: StoreRouter(path: storePath),
                services: ServicesRouter(path: servicesPath)
            )
        )
        _ = lifecycle.restore(from: nil)
        return lifecycle
    }
}
