import Foundation
import OSLog

@MainActor
final class AppSceneNavigationLifecycle {
    let router: AppRouter
    private(set) var hasRestored = false

    private let parser: DeepLinkParser
    private var queuedURLs: [URL] = []

    init() {
        router = AppRouter(flow: .launching)
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

    func synchronizeSession(_ phase: SessionPhase) {
        switch phase {
        case .idle, .loading:
            router.flow = .launching
        case .unauthenticated:
            if router.flow == .launching {
                _ = router.finishLaunching(isAuthenticated: false)
            } else if router.flow == .main {
                router.requireAuthentication()
            }
        case .authenticated:
            if router.flow == .launching {
                _ = router.finishLaunching(isAuthenticated: true)
            } else if router.flow == .authentication {
                _ = router.completeAuthentication(succeeded: true)
            }
        }
    }

    @discardableResult
    func restore(from data: Data?) -> NavigationSnapshot? {
        guard !hasRestored else {
            return nil
        }

        let restorationResult = router.restore(from: data)
        hasRestored = true

        let urls = queuedURLs
        queuedURLs.removeAll()
        urls.forEach(handle)

        if !urls.isEmpty {
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
