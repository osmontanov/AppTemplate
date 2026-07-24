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
        flow: AppFlow,
        selectedSection: AppSection,
        home: HomeRouter,
        browse: BrowseRouter,
        settings: SettingsRouter
    ) {
        self.flow = flow
        self.selectedSection = selectedSection
        self.home = home
        self.browse = browse
        self.settings = settings
    }

    convenience init(
        flow: AppFlow = .main,
        selectedSection: AppSection = .home
    ) {
        self.init(
            flow: flow,
            selectedSection: selectedSection,
            home: HomeRouter(),
            browse: BrowseRouter(),
            settings: SettingsRouter()
        )
    }

    func handle(_ intent: NavigationIntent) -> NavigationOutcome {
        handle(intent, resolver: SampleBrowseCatalog())
    }

    func handle(
        _ intent: NavigationIntent,
        resolver: any BrowseItemResolving
    ) -> NavigationOutcome {
        guard flow == .main else {
            pendingIntent = intent
            return .deferred
        }
        return apply(intent, resolver: resolver)
    }

    func finishLaunching(isAuthenticated: Bool) -> NavigationOutcome? {
        finishLaunching(
            isAuthenticated: isAuthenticated,
            resolver: SampleBrowseCatalog()
        )
    }

    func finishLaunching(
        isAuthenticated: Bool,
        resolver: any BrowseItemResolving
    ) -> NavigationOutcome? {
        flow = isAuthenticated ? .main : .authentication
        guard isAuthenticated else {
            return nil
        }
        return replayPendingIntent(resolver: resolver)
    }

    func completeAuthentication(succeeded: Bool) -> NavigationOutcome? {
        completeAuthentication(
            succeeded: succeeded,
            resolver: SampleBrowseCatalog()
        )
    }

    func completeAuthentication(
        succeeded: Bool,
        resolver: any BrowseItemResolving
    ) -> NavigationOutcome? {
        guard succeeded else {
            pendingIntent = nil
            flow = .authentication
            return nil
        }

        flow = .main
        return replayPendingIntent(resolver: resolver)
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
        case let .openSectionRoot(section):
            openDefaultDestination(for: section)
            return .applied
        case let .browseItem(id):
            guard resolver.item(id: id) != nil else {
                openDefaultDestination(for: .browse)
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

    func openDefaultDestination(for section: AppSection) {
        selectedSection = section
        switch section {
        case .home:
            home.popToRoot()
        case .browse:
            browse.popToRoot()
        case .settings:
            settings.popToRoot()
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
    func restore(from data: Data?) -> NavigationRestorationResult {
        restore(from: data, resolver: SampleBrowseCatalog())
    }

    @discardableResult
    func restore(
        from data: Data?,
        resolver: any BrowseItemResolving
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
        return validBrowsePath.count == decoded.browsePath.count
            ? .restored
            : .restoredAfterPruning
    }

    func resetNavigation() {
        selectedSection = .home
        home.popToRoot()
        browse.popToRoot()
        settings.popToRoot()
    }
}
