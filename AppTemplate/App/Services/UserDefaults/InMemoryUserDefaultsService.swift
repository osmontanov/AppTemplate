import Synchronization

nonisolated
final class InMemoryUserDefaultsService: IUserDefaultsService, Sendable {
    private let namespace: String
    private let values = Mutex<[String: UserDefaultsEncodedValue]>([:])

    init(namespace: String) {
        precondition(UserDefaultsComponent.isValid(namespace))
        self.namespace = namespace
    }

    func value<Value: Sendable>(
        for key: UserDefaultsKey<Value>
    ) throws -> Value? {
        try values.withLock { values in
            guard let encoded = values[physicalKey(for: key)] else { return nil }
            return try key.decode(encoded)
        }
    }

    func set<Value: Sendable>(
        _ value: Value,
        for key: UserDefaultsKey<Value>
    ) throws {
        try values.withLock { values in
            values[physicalKey(for: key)] = try key.encode(value)
        }
    }

    func remove<Value: Sendable>(_ key: UserDefaultsKey<Value>) {
        values.withLock { values in
            values[physicalKey(for: key)] = nil
        }
    }

    private func physicalKey<Value: Sendable>(
        for key: UserDefaultsKey<Value>
    ) -> String {
        "\(namespace).\(key.logicalName)"
    }
}
