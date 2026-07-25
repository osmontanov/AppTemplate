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
        guard flow == .main else {
            pendingIntent = intent
            return .deferred
        }
        return apply(intent)
    }

    func finishLaunching(isAuthenticated: Bool) -> NavigationOutcome? {
        flow = isAuthenticated ? .main : .authentication
        guard isAuthenticated else {
            return nil
        }
        return replayPendingIntent()
    }

    func completeAuthentication(succeeded: Bool) -> NavigationOutcome? {
        guard succeeded else {
            pendingIntent = nil
            flow = .authentication
            return nil
        }

        flow = .main
        return replayPendingIntent()
    }

    private func replayPendingIntent() -> NavigationOutcome? {
        guard let intent = pendingIntent else {
            return nil
        }
        pendingIntent = nil
        return apply(intent)
    }

    private func apply(_ intent: NavigationIntent) -> NavigationOutcome {
        switch intent {
        case let .selectSection(section):
            selectedSection = section
            return .applied
        case let .openSectionRoot(section):
            openDefaultDestination(for: section)
            return .applied
        case let .browseItem(id):
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

        selectedSection = decoded.selectedSection
        home.replacePath(with: decoded.homePath)
        browse.replacePath(with: decoded.browsePath)
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
