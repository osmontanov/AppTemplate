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

    func load() -> AppStateStorageLoadResult {
        guard let value = userDefaults.object(forKey: Self.key) else {
            return .missing
        }
        guard let data = value as? Data else {
            return .invalidValue
        }
        return .data(data)
    }

    func save(_ data: Data) {
        userDefaults.set(data, forKey: Self.key)
    }

    func remove() {
        userDefaults.removeObject(forKey: Self.key)
    }
}
