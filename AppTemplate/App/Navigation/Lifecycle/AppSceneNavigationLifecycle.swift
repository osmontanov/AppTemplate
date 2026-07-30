import Foundation
import OSLog

@MainActor
final class AppSceneNavigationLifecycle {
    let router: AppRouter
    private(set) var hasRestored = false

    private let parser: DeepLinkParser
    private var lastAppliedTransitionID: UUID?
    private var queuedURLs: [URL] = []

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

        let restorationResult = router.restore(from: data)
        let transitionOutcome = apply(transition)
        hasRestored = true

        let urls = queuedURLs
        queuedURLs.removeAll()
        urls.forEach(handle)

        if !urls.isEmpty {
            return router.snapshot
        }
        if transition.historyAction == .reset || transitionOutcome != nil {
            return router.snapshot
        }
        switch restorationResult {
        case .migrated, .recovered, .reset:
            return router.snapshot
        case .noState, .restored:
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
        return router.snapshot
    }

    private func handle(_ url: URL) {
        switch parser.parse(url) {
        case let .success(intent):
            _ = router.handle(intent)
        case let .failure(error):
            _ = router.handle(.openSectionRoot(parser.fallbackSection(for: url)))
            Logger.navigation.error(
                "Rejected deep link: \(String(describing: error), privacy: .public)"
            )
        }
    }
}
