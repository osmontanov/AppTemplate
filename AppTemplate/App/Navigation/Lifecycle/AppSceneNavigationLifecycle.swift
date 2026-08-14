import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class AppSceneNavigationLifecycle: ISceneNavigationActions {
    let router: AppRouter
    private(set) var hasRestored = false
    private(set) var restorationResult: NavigationRestorationResult = .noState

    var snapshot: NavigationSnapshot {
        router.makeSnapshot(lastAppliedTransitionID: lastAppliedTransitionID)
    }

    var snapshotForPersistence: NavigationSnapshot? {
        guard allowsSnapshotPersistence else { return nil }
        return snapshot
    }

    private let parser: DeepLinkParser
    private var allowsSnapshotPersistence = true
    private var lastAppliedTransitionID: UUID?
    private var deferredIntent: NavigationIntent?
    private var deepLinkFailure: DeepLinkFailurePresentation?

    init(appFlowRouter: AppFlowRouter) {
        router = AppRouter(appFlowRouter: appFlowRouter)
        parser = DeepLinkParser()
    }

    init(router: AppRouter) {
        self.router = router
        parser = DeepLinkParser()
    }

    init(router: AppRouter, parser: DeepLinkParser) {
        self.router = router
        self.parser = parser
    }

    @discardableResult
    func apply(_ transition: AppFlowTransition) -> NavigationOutcome? {
        guard transition.id != lastAppliedTransitionID else { return nil }
        lastAppliedTransitionID = transition.id
        let transitionOutcome = router.apply(transition)
        guard hasRestored, router.appFlowRouter.flow == .main,
              let intent = takeDeferredIntent() else {
            return transitionOutcome
        }
        applyIntent(intent)
        return .applied
    }

    @discardableResult
    func restore(from data: Data?) -> NavigationSnapshot? {
        restore(from: data, applying: router.appFlowRouter.transition)
    }

    @discardableResult
    func restore(
        from data: Data?,
        applying transition: AppFlowTransition
    ) -> NavigationSnapshot? {
        guard !hasRestored else { return nil }

        let restoration = router.restore(from: data)
        lastAppliedTransitionID = restoration.lastAppliedTransitionID
        restorationResult = restoration.result
        if case .preservedFutureSchema = restoration.result {
            allowsSnapshotPersistence = false
        } else {
            allowsSnapshotPersistence = true
        }

        let appliesTransition = transition.id != lastAppliedTransitionID
        let transitionOutcome = apply(transition)
        hasRestored = true

        var appliedDeferredIntent = false
        if router.appFlowRouter.flow == .main,
           let intent = takeDeferredIntent() {
            applyIntent(intent)
            appliedDeferredIntent = true
        }

        if appliedDeferredIntent { return snapshotForPersistence }
        if appliesTransition,
           (transition.historyAction == .reset || transitionOutcome != nil) {
            return snapshotForPersistence
        }
        switch restorationResult {
        case .migrated, .recovered, .reset:
            return snapshotForPersistence
        case .noState, .restored, .preservedFutureSchema:
            return nil
        }
    }

    @discardableResult
    func receive(_ url: URL) -> NavigationSnapshot? {
        let intent: NavigationIntent
        switch parser.parse(url) {
        case let .success(value):
            intent = value
            deepLinkFailure = nil
        case let .failure(error):
            deepLinkFailure = DeepLinkFailurePresentation(reason: error)
            Logger.navigation.error("Rejected deep link")
            return nil
        }

        guard hasRestored, router.appFlowRouter.flow == .main else {
            deferredIntent = intent
            return nil
        }
        deferredIntent = nil
        applyIntent(intent)
        return snapshotForPersistence
    }

    func presentation() -> SceneNavigationPresentation {
        SceneNavigationPresentation(
            selectedSection: router.selectedSection,
            storePath: router.store.path,
            servicesPath: router.services.path,
            restorationResult: restorationResult,
            checkpoint: lastAppliedTransitionID,
            hasDeferredLink: deferredIntent != nil,
            hasPendingProtectedAction: false,
            deepLinkFailure: deepLinkFailure
        )
    }

    func resetNavigationInCurrentScene() {
        deferredIntent = nil
        deepLinkFailure = nil
        router.resetNavigation()
    }

    func handleSampleIntent(_ intent: NavigationIntent) {
        applyIntent(intent)
    }

    func recoverRejectedLink(_ action: DeepLinkRecoveryAction) {
        deepLinkFailure = nil
        deferredIntent = nil
        switch action {
        case .openStore: applyIntent(.openStoreRoot)
        case .openServices: applyIntent(.openServicesRoot)
        }
    }

    private func applyIntent(_ intent: NavigationIntent) {
        _ = router.handle(intent)
    }

    private func takeDeferredIntent() -> NavigationIntent? {
        let intent = deferredIntent
        deferredIntent = nil
        return intent
    }
}

extension AppSceneNavigationLifecycle: LocalNotificationSceneReceiving {
    func receiveLocalNotificationURL(_ url: URL) {
        _ = receive(url)
    }
}
