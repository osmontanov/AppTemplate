import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class AppStateStore {
    private(set) var state: AppState
    private(set) var persistenceStatus: AppStatePersistenceStatus

    private let storage: any IAppStateStorage
    private let encode: @Sendable (AppState) throws -> Data

    init(
        storage: any IAppStateStorage,
        encode: @escaping @Sendable (AppState) throws -> Data = {
            try JSONEncoder().encode($0)
        }
    ) {
        self.storage = storage
        self.encode = encode
        state = .initial
        persistenceStatus = .writable

        loadInitialState()
    }

    @discardableResult
    func setState(_ proposedState: AppState) -> AppStateMutationResult {
        guard proposedState != state else { return .unchanged }
        if case let .readOnly(failure) = persistenceStatus {
            return .rejected(failure)
        }
        let data: Data
        do { data = try encode(proposedState) }
        catch { return reject(.encodingFailed) }
        do { try storage.save(data) }
        catch { return reject(.saveFailed) }
        state = proposedState
        return .persisted
    }

    private func loadInitialState() {
        let result: AppStateStorageLoadResult
        do {
            result = try storage.load()
        } catch {
            persistenceStatus = .readOnly(.loadFailed)
            Logger.appState.error("Failed to load persisted app state")
            return
        }

        switch Self.resolve(result) {
        case let .loaded(loadedState):
            state = loadedState
        case let .repair(reason):
            Self.logRecovery(reason)
            repairInitialState()
        case let .futureSchema(version):
            persistenceStatus = .readOnly(.unsupportedFutureSchema(version))
            Logger.appState.error("Unsupported future app state schema")
        }
    }

    private func repairInitialState() {
        let data: Data
        do {
            data = try encode(.initial)
        } catch {
            persistenceStatus = .readOnly(.encodingFailed)
            Logger.appState.error("Failed to encode repaired app state")
            return
        }

        do {
            try storage.save(data)
        } catch {
            persistenceStatus = .readOnly(.saveFailed)
            Logger.appState.error("Failed to save repaired app state")
        }
    }

    private func reject(
        _ failure: AppStatePersistenceFailure
    ) -> AppStateMutationResult {
        persistenceStatus = .readOnly(failure)
        return .rejected(failure)
    }

    private static func resolve(
        _ result: AppStateStorageLoadResult
    ) -> AppStateLoadResolution {
        switch result {
        case .missing:
            return .loaded(.initial)
        case .invalidValue:
            return .repair(.invalidValue)
        case let .data(data):
            return resolve(data)
        }
    }

    private static func resolve(_ data: Data) -> AppStateLoadResolution {
        let decoder = JSONDecoder()
        let envelope: AppStateSchemaEnvelope
        do {
            envelope = try decoder.decode(
                AppStateSchemaEnvelope.self,
                from: data
            )
        } catch {
            return .repair(.corruptData)
        }

        if envelope.schemaVersion > AppState.currentSchemaVersion {
            return .futureSchema(envelope.schemaVersion)
        }

        guard envelope.schemaVersion == AppState.currentSchemaVersion else {
            return .repair(.unsupportedSchema(envelope.schemaVersion))
        }

        do {
            return .loaded(
                try decoder.decode(AppState.self, from: data)
            )
        } catch {
            return .repair(.corruptData)
        }
    }

    private static func logRecovery(_ reason: AppStateRecoveryReason) {
        switch reason {
        case .invalidValue:
            Logger.appState.error(
                "Reset invalid persisted app state value"
            )
        case .corruptData:
            Logger.appState.error(
                "Reset corrupt persisted app state data"
            )
        case .unsupportedSchema:
            Logger.appState.error(
                "Reset unsupported app state schema"
            )
        }
    }
}

private enum AppStateLoadResolution {
    case loaded(AppState)
    case repair(AppStateRecoveryReason)
    case futureSchema(Int)
}

private enum AppStateRecoveryReason {
    case invalidValue
    case corruptData
    case unsupportedSchema(Int)
}

nonisolated
private struct AppStateSchemaEnvelope: Decodable {
    let schemaVersion: Int
}
