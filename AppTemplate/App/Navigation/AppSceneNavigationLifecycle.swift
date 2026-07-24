import Foundation
import OSLog

@MainActor
final class AppSceneNavigationLifecycle {
    let router: AppRouter
    private(set) var hasRestored = false

    private let parser: DeepLinkParser
    private var queuedURLs: [URL] = []

    init() {
        router = AppRouter()
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
        if restorationResult == .restoredAfterPruning {
            return router.snapshot
        }
        if case .reset = restorationResult {
            return router.snapshot
        }
        return nil
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
            router.openDefaultDestination(for: parser.fallbackSection(for: url))
            Logger.navigation.error(
                "Rejected deep link: \(String(describing: error), privacy: .public)"
            )
        }
    }
}
