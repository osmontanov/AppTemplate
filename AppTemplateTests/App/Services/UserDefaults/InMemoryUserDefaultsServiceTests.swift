import Foundation
import Testing
@testable import AppTemplate

nonisolated struct InMemoryUserDefaultsServiceTests {
    @Test
    func allCodecsRoundTripAndRemove() throws {
        let service = InMemoryUserDefaultsService(namespace: "Tests.Codecs")

        try assertRoundTrip(true, key: .bool("Bool"), service: service)
        try assertRoundTrip(17, key: .int("Int"), service: service)
        try assertRoundTrip(Float(1.25), key: .float("Float"), service: service)
        try assertRoundTrip(Double(2.5), key: .double("Double"), service: service)
        try assertRoundTrip("Кыргызча 🌏", key: .string("String"), service: service)
        try assertRoundTrip(Data([0x00, 0x7F, 0xFF]), key: .data("Data"), service: service)
        try assertRoundTrip(
            Date(timeIntervalSinceReferenceDate: 123.5),
            key: .date("Date"),
            service: service
        )
        try assertRoundTrip(
            InMemoryDefaultsFixture(number: 41, label: "fixture"),
            key: .codable("Codable"),
            service: service
        )
    }

    @Test
    func instancesAndNamespacesNeverShareValues() throws {
        let first = InMemoryUserDefaultsService(namespace: "Tests.First")
        let second = InMemoryUserDefaultsService(namespace: "Tests.First")
        let third = InMemoryUserDefaultsService(namespace: "Tests.Second")
        let key = UserDefaultsKey<String>.string("Value")

        try first.set("first", for: key)

        #expect(try first.value(for: key) == "first")
        #expect(try second.value(for: key) == nil)
        #expect(try third.value(for: key) == nil)
    }

    @Test
    func concurrentTypedReadsWritesAndRemovesNeverTearEncodedValues() async throws {
        let service = InMemoryUserDefaultsService(namespace: "Tests.Concurrent")
        let key = UserDefaultsKey<InMemoryDefaultsFixture>.codable("Model")
        let fixtures = (0..<64).map {
            InMemoryDefaultsFixture(number: $0, label: String(repeating: "x", count: 128))
        }

        await withTaskGroup(of: Void.self) { group in
            for fixture in fixtures {
                group.addTask {
                    for iteration in 0..<100 {
                        do {
                            try service.set(fixture, for: key)
                            if let value = try service.value(for: key) {
                                #expect(fixtures.contains(value))
                            }
                            if iteration.isMultiple(of: 7) {
                                service.remove(key)
                            }
                        } catch {
                            Issue.record("Unexpected codec failure: \(type(of: error))")
                        }
                    }
                }
            }
        }

        if let value = try service.value(for: key) {
            #expect(fixtures.contains(value))
        }
    }

    private func assertRoundTrip<Value: Equatable & Sendable>(
        _ value: Value,
        key: UserDefaultsKey<Value>,
        service: InMemoryUserDefaultsService
    ) throws {
        #expect(try service.value(for: key) == nil)
        try service.set(value, for: key)
        #expect(try service.value(for: key) == value)
        service.remove(key)
        #expect(try service.value(for: key) == nil)
    }
}

private nonisolated struct InMemoryDefaultsFixture: Codable, Equatable, Sendable {
    let number: Int
    let label: String
}
