import Foundation

nonisolated struct UserDefaultsAppStateStorage: IAppStateStorage, Sendable {
    private static let appStateKey: UserDefaultsKey<Data> = .data("AppState")

    private let userDefaults: any IUserDefaultsService

    init(userDefaults: any IUserDefaultsService) {
        self.userDefaults = userDefaults
    }

    func load() throws -> AppStateStorageLoadResult {
        do {
            guard let data = try userDefaults.value(for: Self.appStateKey) else {
                return .missing
            }
            return .data(data)
        } catch UserDefaultsServiceError.invalidStoredValue {
            return .invalidValue
        }
    }

    func save(_ data: Data) throws {
        try userDefaults.set(data, for: Self.appStateKey)
    }

    func remove() throws {
        userDefaults.remove(Self.appStateKey)
    }
}
