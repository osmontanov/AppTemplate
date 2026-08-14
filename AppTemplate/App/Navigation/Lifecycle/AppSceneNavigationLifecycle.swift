import Foundation
import OSLog

@MainActor
final class AppSceneNavigationLifecycle {
    let router: AppRouter
    private(set) var hasRestored = false
    private(set) var restorationResult: NavigationRestorationResult = .noState

    var snapshot: NavigationSnapshot {
        router.makeSnapshot(
            lastAppliedTransitionID: lastAppliedTransitionID
        )
    }

    var snapshotForPersistence: NavigationSnapshot? {
        guard allowsSnapshotPersistence else {
            return nil
        }
        return snapshot
    }

    private let parser: DeepLinkParser
    private var allowsSnapshotPersistence = true
    private var lastAppliedTransitionID: UUID?
    private var queuedURLs: [URL] = []

    init(
        appFlowRouter: AppFlowRouter
    ) {
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
        guard transition.id != lastAppliedTransitionID else {
            return nil
        }
        lastAppliedTransitionID = transition.id
        return router.apply(transition)
    }

    @discardableResult
    func restore(from data: Data?) -> NavigationSnapshot? {
        restore(
            from: data,
            applying: router.appFlowRouter.transition
        )
    }

    @discardableResult
    func restore(
        from data: Data?,
        applying transition: AppFlowTransition
    ) -> NavigationSnapshot? {
        guard !hasRestored else {
            return nil
        }

        let restoration = router.restore(from: data)
        lastAppliedTransitionID = restoration.lastAppliedTransitionID
        restorationResult = restoration.result
        switch restoration.result {
        case .preservedFutureSchema:
            allowsSnapshotPersistence = false
        default:
            allowsSnapshotPersistence = true
        }
        let appliesTransition = transition.id != lastAppliedTransitionID
        let transitionOutcome = apply(transition)
        hasRestored = true

        let urls = queuedURLs
        queuedURLs.removeAll()
        urls.forEach(handle)

        if !urls.isEmpty {
            return snapshotForPersistence
        }
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
        guard hasRestored else {
            queuedURLs.append(url)
            return nil
        }

        handle(url)
        return snapshotForPersistence
    }

    private func handle(_ url: URL) {
        switch parser.parse(url) {
        case let .success(intent):
            _ = router.handle(intent)
        case let .failure(error):
            let fallback = parser.fallbackSection(for: url)
            _ = router.handle(
                fallback == .store ? .openStoreRoot : .openServicesRoot
            )
            Logger.navigation.error(
                "Rejected deep link: \(String(describing: error), privacy: .public)"
            )
        }
    }
}

extension AppSceneNavigationLifecycle: LocalNotificationSceneReceiving {
    func receiveLocalNotificationURL(_ url: URL) {
        _ = receive(url)
    }
}
