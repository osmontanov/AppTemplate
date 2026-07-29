import Foundation
import Observation
import OSLog
import SwiftUI

@MainActor
@Observable
final class AppRouter {
    var flow: AppFlow
    var selectedSection: AppSection
    let authentication: FlowRouter
    let home: FlowRouter
    let browse: FlowRouter
    let settings: FlowRouter
    private(set) var pendingIntent: NavigationIntent?

    init(
        flow: AppFlow,
        selectedSection: AppSection,
        authentication: FlowRouter,
        home: FlowRouter,
        browse: FlowRouter,
        settings: FlowRouter
    ) {
        self.flow = flow
        self.selectedSection = selectedSection
        self.authentication = authentication
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
            authentication: FlowRouter(),
            home: FlowRouter(),
            browse: FlowRouter(),
            settings: FlowRouter()
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
        guard isAuthenticated else {
            resetFlowHistories()
            flow = .authentication
            return nil
        }

        authentication.popToRoot()
        flow = .main
        return replayPendingIntent()
    }

    func completeAuthentication(succeeded: Bool) -> NavigationOutcome? {
        guard succeeded else {
            pendingIntent = nil
            authentication.popToRoot()
            flow = .authentication
            return nil
        }

        resetFlowHistories()
        flow = .main
        return replayPendingIntent()
    }

    func requireAuthentication() {
        pendingIntent = nil
        resetFlowHistories()
        flow = .authentication
    }

    func openDefaultDestination(for section: AppSection) {
        selectedSection = section
        router(for: section).popToRoot()
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
        case let .openSectionRoot(section):
            openDefaultDestination(for: section)
        case let .browseItem(id):
            selectedSection = .browse
            browse.popToRoot()
            browse.push(BrowseRoute.item(id: id))
        }
        return .applied
    }

    private func router(for section: AppSection) -> FlowRouter {
        switch section {
        case .home:
            home
        case .browse:
            browse
        case .settings:
            settings
        }
    }

    private func resetFlowHistories() {
        selectedSection = .home
        authentication.popToRoot()
        home.popToRoot()
        browse.popToRoot()
        settings.popToRoot()
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

        let schemaVersion: Int
        do {
            schemaVersion = try NavigationSnapshotCodec.schemaVersion(in: data)
        } catch {
            resetNavigation()
            Logger.navigation.error(
                "Reset corrupt navigation snapshot: \(String(describing: error), privacy: .public)"
            )
            return .reset(.corruptData)
        }

        guard schemaVersion == NavigationSnapshot.currentSchemaVersion else {
            resetNavigation()
            Logger.navigation.error(
                "Reset unsupported navigation schema: \(schemaVersion)"
            )
            return .reset(.unsupportedSchema(schemaVersion))
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

        let homePath = decoded.homePath.restoredPath
        let browsePath = decoded.browsePath.restoredPath
        let settingsPath = decoded.settingsPath.restoredPath
        var recoveredSections: Set<AppSection> = []
        if homePath == nil {
            recoveredSections.insert(.home)
        }
        if browsePath == nil {
            recoveredSections.insert(.browse)
        }
        if settingsPath == nil {
            recoveredSections.insert(.settings)
        }

        selectedSection = decoded.selectedSection
        authentication.popToRoot()
        home.replacePath(with: homePath ?? .init())
        browse.replacePath(with: browsePath ?? .init())
        settings.replacePath(with: settingsPath ?? .init())
        pendingIntent = nil

        guard recoveredSections.isEmpty else {
            let names = recoveredSections
                .map(\.rawValue)
                .sorted()
                .joined(separator: ", ")
            Logger.navigation.error(
                "Reset non-restorable navigation flows: \(names, privacy: .public)"
            )
            return .recovered(recoveredSections)
        }
        return .restored
    }

    func resetNavigation() {
        pendingIntent = nil
        resetFlowHistories()
    }
}
