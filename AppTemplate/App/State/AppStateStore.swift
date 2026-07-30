import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class AppStateStore {
    private(set) var state: AppState
    private let storage: any IAppStateStorage

    init(storage: any IAppStateStorage) {
        self.storage = storage

        switch Self.resolve(storage.load()) {
        case let .loaded(state):
            self.state = state
        case let .recovered(reason):
            state = .initial
            Self.logRecovery(reason)
            persist(state)
        }
    }

    @discardableResult
    func setState(_ state: AppState) -> Bool {
        guard state != self.state else {
            return false
        }
        self.state = state
        persist(state)
        return true
    }

    private func persist(_ state: AppState) {
        do {
            storage.save(try JSONEncoder().encode(state))
        } catch {
            Logger.appState.error("Failed to encode persisted app state")
        }
    }

    private static func resolve(
        _ result: AppStateStorageLoadResult
    ) -> AppStateLoadResolution {
        switch result {
        case .missing:
            return .loaded(.initial)
        case .invalidValue:
            return .recovered(.invalidValue)
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
            return .recovered(.corruptData)
        }

        guard envelope.schemaVersion == AppState.currentSchemaVersion else {
            return .recovered(
                .unsupportedSchema(envelope.schemaVersion)
            )
        }

        do {
            return .loaded(
                try decoder.decode(AppState.self, from: data)
            )
        } catch {
            return .recovered(.corruptData)
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
    case recovered(AppStateRecoveryReason)
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
