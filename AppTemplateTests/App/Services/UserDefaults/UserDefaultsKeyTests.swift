import Foundation
import Testing
@testable import AppTemplate

struct UserDefaultsKeyTests {
    @Test func nativeFactoriesExposeExpectedKinds() throws {
        constructEveryFactoryFromNonisolatedContext()
        #expect(UserDefaultsKey<Bool>.bool("Flag").physicalKind == .bool)
        #expect(UserDefaultsKey<Int>.int("Count").physicalKind == .int)
        #expect(UserDefaultsKey<Float>.float("Ratio32").physicalKind == .float)
        #expect(UserDefaultsKey<Double>.double("Ratio64").physicalKind == .double)
        #expect(UserDefaultsKey<String>.string("Name").physicalKind == .string)
        #expect(UserDefaultsKey<Data>.data("Blob").physicalKind == .data)
        #expect(UserDefaultsKey<Date>.date("Date").physicalKind == .date)
    }

    @Test func codableFactoryUsesRawJSONData() throws {
        let key = UserDefaultsKey<KeyFixture>.codable("Fixture")
        let encoded = try key.encode(KeyFixture(value: 7))
        guard case let .data(data) = encoded else {
            Issue.record("Codable key must encode to Data")
            return
        }
        #expect(try JSONDecoder().decode(KeyFixture.self, from: data) == .init(value: 7))
        #expect(try key.decode(.data(data)) == .init(value: 7))
    }

    @Test func componentsValidateWithoutNormalizingValidSpelling() {
        #expect(UserDefaultsComponent.isValid("  Exact Name  "))
        #expect(!UserDefaultsComponent.isValid(" \n\t "))
        #expect(UserDefaultsKey<String>.string("  Exact Name  ").logicalName == "  Exact Name  ")
    }

    #if os(macOS)
    @Test func blankLogicalNameTerminates() async {
        await #expect(processExitsWith: .failure) {
            _ = UserDefaultsKey<String>.string(" \n\t ")
        }
    }
    #endif

    @Test func genericContractWorksThroughExistential() throws {
        let service: any IUserDefaultsService = NoOpUserDefaultsService()
        let key = UserDefaultsKey<Bool>.bool("Flag")
        #expect(try service.value(for: key) == nil)
        try service.set(true, for: key)
        service.remove(key)
    }
}

nonisolated private struct KeyFixture: Codable, Equatable, Sendable { let value: Int }

nonisolated private func constructEveryFactoryFromNonisolatedContext() {
    _ = UserDefaultsKey<Bool>.bool("Flag")
    _ = UserDefaultsKey<Int>.int("Count")
    _ = UserDefaultsKey<Float>.float("Ratio32")
    _ = UserDefaultsKey<Double>.double("Ratio64")
    _ = UserDefaultsKey<String>.string("Name")
    _ = UserDefaultsKey<Data>.data("Blob")
    _ = UserDefaultsKey<Date>.date("Date")
    _ = UserDefaultsKey<KeyFixture>.codable("Fixture")
}

nonisolated private struct NoOpUserDefaultsService: IUserDefaultsService {
    func value<Value: Sendable>(for key: UserDefaultsKey<Value>) throws -> Value? { nil }
    func set<Value: Sendable>(_ value: Value, for key: UserDefaultsKey<Value>) throws {}
    func remove<Value: Sendable>(_ key: UserDefaultsKey<Value>) {}
}
