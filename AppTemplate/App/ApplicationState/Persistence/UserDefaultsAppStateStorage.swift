import Foundation

nonisolated
struct UserDefaultsAppStateStorage:
    IAppStateStorage,
    @unchecked Sendable
{
    static let key = "AppTemplate.AppState"

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() throws -> AppStateStorageLoadResult {
        guard let value = userDefaults.object(forKey: Self.key) else {
            return .missing
        }
        guard let data = value as? Data else {
            return .invalidValue
        }
        return .data(data)
    }

    func save(_ data: Data) throws {
        userDefaults.set(data, forKey: Self.key)
    }

    func remove() throws {
        userDefaults.removeObject(forKey: Self.key)
    }
}
