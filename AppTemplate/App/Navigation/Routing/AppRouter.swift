import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class AppRouter {
    let appFlowRouter: AppFlowRouter
    var selectedSection: AppSection
    let store: StoreRouter
    let services: ServicesRouter

    init(
        appFlowRouter: AppFlowRouter,
        selectedSection: AppSection = .store,
        store: StoreRouter = StoreRouter(),
        services: ServicesRouter = ServicesRouter()
    ) {
        self.appFlowRouter = appFlowRouter
        self.selectedSection = selectedSection
        self.store = store
        self.services = services
    }

    @discardableResult
    func apply(_ transition: AppFlowTransition) -> NavigationOutcome? {
        if transition.historyAction == .reset { resetHistories() }
        return nil
    }

    func handle(_ intent: NavigationIntent) -> NavigationOutcome {
        return apply(intent)
    }

    func reconcile(
        _ presentation: SessionPresentation
    ) -> ProtectedStoreAction? {
        store.reconcile(presentation)
    }

    func openDefaultDestination(for section: AppSection) {
        selectedSection = section
        switch section {
        case .store: store.reset()
        case .services: services.reset()
        }
    }

    private func apply(_ intent: NavigationIntent) -> NavigationOutcome {
        switch intent {
        case .openStoreRoot: openDefaultDestination(for: .store)
        case let .openProduct(id):
            selectedSection = .store
            store.replace(with: .product(id))
        case .openFavorites:
            selectedSection = .store
            store.replace(with: .favorites)
        case .openProfile:
            selectedSection = .store
            store.replace(with: .profile)
        case .openServicesRoot: openDefaultDestination(for: .services)
        case let .openService(route):
            selectedSection = .services
            services.path = [route]
        }
        return .applied
    }

    var snapshot: NavigationSnapshot {
        makeSnapshot(lastAppliedTransitionID: nil)
    }

    func makeSnapshot(lastAppliedTransitionID: UUID?) -> NavigationSnapshot {
        NavigationSnapshot(
            lastAppliedTransitionID: lastAppliedTransitionID,
            selectedSection: selectedSection,
            storePath: store.path,
            servicesPath: services.path
        )
    }

    @discardableResult
    func restore(from data: Data?) -> NavigationRestoration {
        guard let data else {
            return NavigationRestoration(result: .noState, lastAppliedTransitionID: nil)
        }
        let schemaVersion: Int
        do {
            schemaVersion = try NavigationSnapshotCodec.schemaVersion(in: data)
        } catch {
            return resetAfterFailure(.corruptData, error: error)
        }

        switch schemaVersion {
        case NavigationSnapshot.currentSchemaVersion:
            do {
                let recovered = try NavigationSnapshotCodec.decodeRecoveringSchemaFive(data)
                apply(recovered.snapshot)
                let result: NavigationRestorationResult = recovered.recoveredSections.isEmpty
                    ? .restored
                    : .recovered(recovered.recoveredSections)
                return NavigationRestoration(
                    result: result,
                    lastAppliedTransitionID: recovered.snapshot.lastAppliedTransitionID
                )
            } catch {
                return resetAfterFailure(.corruptData, error: error)
            }
        case 2:
            return migrate(LegacyNavigationSnapshotV2.self, from: data, schemaVersion: 2)
        case 3:
            return migrate(LegacyNavigationSnapshotV3.self, from: data, schemaVersion: 3)
        case 4:
            do {
                let legacy = try JSONDecoder().decode(LegacyNavigationSnapshotV4.self, from: data)
                resetNavigation()
                return NavigationRestoration(
                    result: .migrated(from: 4),
                    lastAppliedTransitionID: legacy.lastAppliedTransitionID
                )
            } catch {
                return resetAfterFailure(.corruptData, error: error)
            }
        case let future where future > NavigationSnapshot.currentSchemaVersion:
            resetNavigation()
            Logger.navigation.error("Preserved future navigation schema: \(future)")
            return NavigationRestoration(result: .preservedFutureSchema(future), lastAppliedTransitionID: nil)
        default:
            return resetAfterFailure(.unsupportedSchema(schemaVersion), error: nil)
        }
    }

    func resetNavigation() {
        resetHistories()
    }

    private func resetHistories() {
        selectedSection = .store
        store.reset()
        services.reset()
    }

    private func apply(_ snapshot: NavigationSnapshot) {
        selectedSection = snapshot.selectedSection
        store.reset()
        store.path = snapshot.storePath
        services.path = snapshot.servicesPath
    }

    private func migrate<Value: Decodable>(
        _ type: Value.Type,
        from data: Data,
        schemaVersion: Int
    ) -> NavigationRestoration {
        do {
            _ = try JSONDecoder().decode(type, from: data)
            resetNavigation()
            return NavigationRestoration(result: .migrated(from: schemaVersion), lastAppliedTransitionID: nil)
        } catch {
            return resetAfterFailure(.corruptData, error: error)
        }
    }

    private func resetAfterFailure(
        _ failure: NavigationRestorationFailure,
        error: Error?
    ) -> NavigationRestoration {
        resetNavigation()
        Logger.navigation.error("Reset navigation snapshot: \(String(describing: error), privacy: .public)")
        return NavigationRestoration(result: .reset(failure), lastAppliedTransitionID: nil)
    }
}

private nonisolated struct LegacyNavigationSnapshotV2: Decodable {
    let schemaVersion: Int
    let selectedSection: String
    let homePath: FlowPathSnapshot
    let browsePath: FlowPathSnapshot
    let settingsPath: FlowPathSnapshot
}

private nonisolated struct LegacyNavigationSnapshotV3: Decodable {
    let schemaVersion: Int
    let selectedSection: String
    let homePath: FlowPathSnapshot
    let browsePath: FlowPathSnapshot
    let projectsPath: FlowPathSnapshot
    let settingsPath: FlowPathSnapshot
}

private nonisolated struct LegacyNavigationSnapshotV4: Decodable {
    let schemaVersion: Int
    let lastAppliedTransitionID: UUID?
    let selectedSection: String
    let homePath: FlowPathSnapshot
    let browsePath: FlowPathSnapshot
    let projectsPath: FlowPathSnapshot
    let settingsPath: FlowPathSnapshot
}
