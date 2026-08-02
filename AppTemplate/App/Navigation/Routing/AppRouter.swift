import Foundation
import Observation
import OSLog
import SwiftUI

@MainActor
@Observable
final class AppRouter: IAuthenticationCancellation {
    let appFlowRouter: AppFlowRouter
    var selectedSection: AppSection
    let authentication: FlowRouter
    let onboarding: FlowRouter
    let home: FlowRouter
    let browse: FlowRouter
    let projects: FlowRouter
    let settings: FlowRouter
    let maintenance: FlowRouter
    private(set) var pendingIntent: NavigationIntent?

    init(
        appFlowRouter: AppFlowRouter,
        appFlowCoordinator: any IAppFlowCoordinator,
        selectedSection: AppSection = .home
    ) {
        self.appFlowRouter = appFlowRouter
        self.selectedSection = selectedSection
        authentication = FlowRouter(appFlowCoordinator: appFlowCoordinator)
        onboarding = FlowRouter(appFlowCoordinator: appFlowCoordinator)
        home = FlowRouter(appFlowCoordinator: appFlowCoordinator)
        browse = FlowRouter(appFlowCoordinator: appFlowCoordinator)
        projects = FlowRouter(appFlowCoordinator: appFlowCoordinator)
        settings = FlowRouter(appFlowCoordinator: appFlowCoordinator)
        maintenance = FlowRouter(appFlowCoordinator: appFlowCoordinator)
    }

    @discardableResult
    func apply(_ transition: AppFlowTransition) -> NavigationOutcome? {
        if transition.historyAction == .reset {
            resetFlowHistories()
        }

        switch transition.pendingIntentAction {
        case .preserve:
            return nil
        case .discard:
            pendingIntent = nil
            return nil
        case .replay:
            return replayPendingIntent()
        }
    }

    func handle(_ intent: NavigationIntent) -> NavigationOutcome {
        guard appFlowRouter.flow == .main else {
            pendingIntent = intent
            return .deferred
        }
        return apply(intent)
    }

    func openDefaultDestination(for section: AppSection) {
        selectedSection = section
        router(for: section).popToRoot()
    }

    func cancelAuthentication() {
        authentication.popToRoot()
        pendingIntent = nil
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
        case let .project(id):
            selectedSection = .projects
            projects.popToRoot()
            projects.push(ProjectsRoute.project(id: id))
        case let .projectTask(projectID, taskID):
            selectedSection = .projects
            projects.popToRoot()
            projects.push(ProjectsRoute.project(id: projectID))
            projects.push(
                ProjectDetailsRoute.task(
                    projectID: projectID,
                    taskID: taskID
                )
            )
        }
        return .applied
    }

    private func router(for section: AppSection) -> FlowRouter {
        switch section {
        case .home:
            home
        case .browse:
            browse
        case .projects:
            projects
        case .settings:
            settings
        }
    }

    private func resetFlowHistories() {
        selectedSection = .home
        authentication.popToRoot()
        onboarding.popToRoot()
        home.popToRoot()
        browse.popToRoot()
        projects.popToRoot()
        settings.popToRoot()
        maintenance.popToRoot()
    }
}

extension AppRouter {
    var snapshot: NavigationSnapshot {
        makeSnapshot(lastAppliedTransitionID: nil)
    }

    func makeSnapshot(
        lastAppliedTransitionID: UUID?
    ) -> NavigationSnapshot {
        NavigationSnapshot(
            lastAppliedTransitionID: lastAppliedTransitionID,
            selectedSection: selectedSection,
            homePath: home.path,
            browsePath: browse.path,
            projectsPath: projects.path,
            settingsPath: settings.path
        )
    }

    @discardableResult
    func restore(from data: Data?) -> NavigationRestoration {
        guard let data else {
            return NavigationRestoration(
                result: .noState,
                lastAppliedTransitionID: nil
            )
        }

        let schemaVersion: Int
        do {
            schemaVersion = try NavigationSnapshotCodec.schemaVersion(in: data)
        } catch {
            resetNavigation()
            Logger.navigation.error(
                "Reset corrupt navigation snapshot: \(String(describing: error), privacy: .public)"
            )
            return NavigationRestoration(
                result: .reset(.corruptData),
                lastAppliedTransitionID: nil
            )
        }

        switch schemaVersion {
        case NavigationSnapshot.currentSchemaVersion:
            let decoded: NavigationSnapshot
            do {
                decoded = try NavigationSnapshotCodec.decode(data)
            } catch {
                resetNavigation()
                Logger.navigation.error(
                    "Reset corrupt navigation snapshot: \(String(describing: error), privacy: .public)"
                )
                return NavigationRestoration(
                    result: .reset(.corruptData),
                    lastAppliedTransitionID: nil
                )
            }
            return NavigationRestoration(
                result: restore(
                    selectedSection: decoded.selectedSection,
                    homeSnapshot: decoded.homePath,
                    browseSnapshot: decoded.browsePath,
                    projectsSnapshot: decoded.projectsPath,
                    settingsSnapshot: decoded.settingsPath
                ),
                lastAppliedTransitionID: decoded.lastAppliedTransitionID
            )
        case 3:
            let decoded: NavigationSnapshotV3
            do {
                decoded = try JSONDecoder().decode(
                    NavigationSnapshotV3.self,
                    from: data
                )
            } catch {
                resetNavigation()
                Logger.navigation.error(
                    "Reset corrupt navigation snapshot: \(String(describing: error), privacy: .public)"
                )
                return NavigationRestoration(
                    result: .reset(.corruptData),
                    lastAppliedTransitionID: nil
                )
            }
            let result = restore(
                selectedSection: decoded.selectedSection,
                homeSnapshot: decoded.homePath,
                browseSnapshot: decoded.browsePath,
                projectsSnapshot: decoded.projectsPath,
                settingsSnapshot: decoded.settingsPath
            )
            return NavigationRestoration(
                result: result == .restored ? .migrated(from: 3) : result,
                lastAppliedTransitionID: nil
            )
        case 2:
            let decoded: NavigationSnapshotV2
            do {
                decoded = try JSONDecoder().decode(
                    NavigationSnapshotV2.self,
                    from: data
                )
            } catch {
                resetNavigation()
                Logger.navigation.error(
                    "Reset corrupt navigation snapshot: \(String(describing: error), privacy: .public)"
                )
                return NavigationRestoration(
                    result: .reset(.corruptData),
                    lastAppliedTransitionID: nil
                )
            }
            let result = restore(
                selectedSection: decoded.selectedSection,
                homeSnapshot: decoded.homePath,
                browseSnapshot: decoded.browsePath,
                projectsSnapshot: nil,
                settingsSnapshot: decoded.settingsPath
            )
            return NavigationRestoration(
                result: result == .restored ? .migrated(from: 2) : result,
                lastAppliedTransitionID: nil
            )
        case let futureVersion
            where futureVersion > NavigationSnapshot.currentSchemaVersion:
            resetNavigation()
            Logger.navigation.error(
                "Preserved future navigation schema: \(futureVersion)"
            )
            return NavigationRestoration(
                result: .preservedFutureSchema(futureVersion),
                lastAppliedTransitionID: nil
            )
        default:
            resetNavigation()
            Logger.navigation.error(
                "Reset unsupported navigation schema: \(schemaVersion)"
            )
            return NavigationRestoration(
                result: .reset(.unsupportedSchema(schemaVersion)),
                lastAppliedTransitionID: nil
            )
        }
    }

    private func restore(
        selectedSection: AppSection,
        homeSnapshot: FlowPathSnapshot,
        browseSnapshot: FlowPathSnapshot,
        projectsSnapshot: FlowPathSnapshot?,
        settingsSnapshot: FlowPathSnapshot
    ) -> NavigationRestorationResult {
        let homePath = homeSnapshot.restoredPath
        let browsePath = browseSnapshot.restoredPath
        let projectsPath = projectsSnapshot?.restoredPath
        let settingsPath = settingsSnapshot.restoredPath
        var recoveredSections: Set<AppSection> = []
        if homePath == nil {
            recoveredSections.insert(.home)
        }
        if browsePath == nil {
            recoveredSections.insert(.browse)
        }
        if projectsSnapshot != nil, projectsPath == nil {
            recoveredSections.insert(.projects)
        }
        if settingsPath == nil {
            recoveredSections.insert(.settings)
        }

        self.selectedSection = selectedSection
        authentication.popToRoot()
        onboarding.popToRoot()
        home.replacePath(with: homePath ?? .init())
        browse.replacePath(with: browsePath ?? .init())
        projects.replacePath(with: projectsPath ?? .init())
        settings.replacePath(with: settingsPath ?? .init())
        maintenance.popToRoot()
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

private
nonisolated
struct NavigationSnapshotV3: Decodable {
    let schemaVersion: Int
    let selectedSection: AppSection
    let homePath: FlowPathSnapshot
    let browsePath: FlowPathSnapshot
    let projectsPath: FlowPathSnapshot
    let settingsPath: FlowPathSnapshot
}

private
nonisolated
struct NavigationSnapshotV2: Decodable {
    let schemaVersion: Int
    let selectedSection: AppSection
    let homePath: FlowPathSnapshot
    let browsePath: FlowPathSnapshot
    let settingsPath: FlowPathSnapshot
}
