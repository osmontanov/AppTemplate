nonisolated protocol IUserDefaultsService: Sendable {
    func value<Value: Sendable>(for key: UserDefaultsKey<Value>) throws -> Value?
    func set<Value: Sendable>(_ value: Value, for key: UserDefaultsKey<Value>) throws
    func remove<Value: Sendable>(_ key: UserDefaultsKey<Value>)
}
