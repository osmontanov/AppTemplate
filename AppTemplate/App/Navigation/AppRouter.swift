import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class AppRouter {
    var flow: AppFlow
    var selectedSection: AppSection
    let home: HomeRouter
    let browse: BrowseRouter
    let settings: SettingsRouter
    private(set) var pendingIntent: NavigationIntent?

    init(
        flow: AppFlow = .main,
        selectedSection: AppSection = .home,
        home: HomeRouter? = nil,
        browse: BrowseRouter? = nil,
        settings: SettingsRouter? = nil
    ) {
        self.flow = flow
        self.selectedSection = selectedSection
        self.home = home ?? HomeRouter()
        self.browse = browse ?? BrowseRouter()
        self.settings = settings ?? SettingsRouter()
    }

    func handle(
        _ intent: NavigationIntent,
        resolver: (any BrowseItemResolving)? = nil
    ) -> NavigationOutcome {
        guard flow == .main else {
            pendingIntent = intent
            return .deferred
        }
        return apply(intent, resolver: resolver ?? SampleBrowseCatalog())
    }

    func finishLaunching(
        isAuthenticated: Bool,
        resolver: (any BrowseItemResolving)? = nil
    ) -> NavigationOutcome? {
        flow = isAuthenticated ? .main : .authentication
        guard isAuthenticated else {
            return nil
        }
        return replayPendingIntent(resolver: resolver ?? SampleBrowseCatalog())
    }

    func completeAuthentication(
        succeeded: Bool,
        resolver: (any BrowseItemResolving)? = nil
    ) -> NavigationOutcome? {
        guard succeeded else {
            pendingIntent = nil
            flow = .authentication
            return nil
        }

        flow = .main
        return replayPendingIntent(resolver: resolver ?? SampleBrowseCatalog())
    }

    private func replayPendingIntent(
        resolver: any BrowseItemResolving
    ) -> NavigationOutcome? {
        guard let intent = pendingIntent else {
            return nil
        }
        pendingIntent = nil
        return apply(intent, resolver: resolver)
    }

    private func apply(
        _ intent: NavigationIntent,
        resolver: any BrowseItemResolving
    ) -> NavigationOutcome {
        switch intent {
        case let .selectSection(section):
            selectedSection = section
            return .applied
        case let .browseItem(id):
            guard resolver.item(id: id) != nil else {
                Logger.navigation.error(
                    "Rejected unavailable Browse identifier: \(id, privacy: .public)"
                )
                return .rejected(.missingBrowseItem(id))
            }
            selectedSection = .browse
            browse.replacePath(with: [.item(id: id)])
            return .applied
        }
    }
}

extension AppRouter {
    var snapshot: NavigationSnapshot {
        NavigationSnapshot(
            selectedSection: selectedSection,
            homePath: home.path,
            browsePath: browse.path,
            settingsPath: settings.path
        )
    }

    @discardableResult
    func restore(
        from data: Data?,
        resolver: (any BrowseItemResolving)? = nil
    ) -> NavigationRestorationResult {
        guard let data else {
            return .noState
        }

        let decoded: NavigationSnapshot
        do {
            decoded = try NavigationSnapshotCodec.decode(data)
        } catch {
            resetNavigation()
            Logger.navigation.error(
                "Reset corrupt navigation snapshot: \(String(describing: error), privacy: .public)"
            )
            return .reset(.corruptData)
        }

        guard decoded.schemaVersion == NavigationSnapshot.currentSchemaVersion else {
            resetNavigation()
            Logger.navigation.error(
                "Reset unsupported navigation schema: \(decoded.schemaVersion)"
            )
            return .reset(.unsupportedSchema(decoded.schemaVersion))
        }

        let resolver = resolver ?? SampleBrowseCatalog()
        let validBrowsePath = decoded.browsePath.filter { route in
            switch route {
            case let .item(id):
                resolver.item(id: id) != nil
            }
        }

        selectedSection = decoded.selectedSection
        home.replacePath(with: decoded.homePath)
        browse.replacePath(with: validBrowsePath)
        settings.replacePath(with: decoded.settingsPath)
        return .restored
    }

    func resetNavigation() {
        selectedSection = .home
        home.popToRoot()
        browse.popToRoot()
        settings.popToRoot()
    }
}
