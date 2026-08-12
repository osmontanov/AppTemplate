import Foundation
import Testing
@testable import AppTemplate

struct KeychainConvenienceTests {
    @Test func dataPassesThroughWithoutTransformation() async throws {
        let service = KeychainServiceSpy()
        let key = KeychainKey.data("Bytes")
        let bytes = Data([0x00, 0xFF, 0x41])
        try await service.set(bytes, for: key)
        #expect(try await service.data(for: key) == bytes)
    }

    @Test func unicodeStringRoundTripsAndEmptyStringIsPresent() async throws {
        let service = KeychainServiceSpy()
        let unicode = KeychainKey.data("Unicode")
        let empty = KeychainKey.data("Empty")
        try await service.set("Привет 🌍", for: unicode)
        try await service.set("", for: empty)
        #expect(try await service.string(for: unicode) == "Привет 🌍")
        #expect(try await service.string(for: empty) == "")
    }

    @Test func invalidUTF8ThrowsWithoutChangingStoredBytes() async throws {
        let key = KeychainKey.data("Invalid UTF8")
        let bytes = Data([0xC3, 0x28])
        let service = KeychainServiceSpy(storage: [key: bytes])
        await #expect(throws: KeychainServiceError.invalidUTF8) {
            _ = try await service.string(for: key)
        }
        #expect(await service.storedData(for: key) == bytes)
    }

    @Test func codableModelsRoundTripAndSchemaVersionsCoexist() async throws {
        let service = KeychainServiceSpy()
        let first: KeychainCodableKey<FirstSecret> = .codable("Session", schemaVersion: 1)
        let second: KeychainCodableKey<UnicodeSecret> = .codable("Session", schemaVersion: 2)
        try await service.set(FirstSecret(value: 7), for: first)
        try await service.set(UnicodeSecret(title: "Кыргызча", enabled: true), for: second)
        #expect(try await service.value(for: first) == FirstSecret(value: 7))
        #expect(try await service.value(for: second) == UnicodeSecret(title: "Кыргызча", enabled: true))
    }

    @Test func encodingFailureMakesNoRawServiceCall() async {
        let service = KeychainServiceSpy()
        let key: KeychainCodableKey<FailingEncodeSecret> = .codable("Failure", schemaVersion: 1)
        await #expect(throws: KeychainServiceError.encodingFailed) {
            try await service.set(FailingEncodeSecret(), for: key)
        }
        let counts = await service.callCounts()
        #expect(counts.reads == 0 && counts.writes == 0 && counts.removals == 0)
    }

    @Test func decodingFailureLeavesStoredBytesUntouched() async throws {
        let key: KeychainCodableKey<FirstSecret> = .codable("Decode", schemaVersion: 1)
        let raw = KeychainKey(validatedPhysicalAccount: key.account)
        let bytes = Data("not-json".utf8)
        let service = KeychainServiceSpy(storage: [raw: bytes])
        await #expect(throws: KeychainServiceError.decodingFailed) {
            _ = try await service.value(for: key)
        }
        #expect(await service.storedData(for: raw) == bytes)
    }

    @Test func codecCancellationRemainsCancellationError() async {
        let setService = KeychainServiceSpy()
        let key: KeychainCodableKey<CancellingCodecSecret> = .codable("Cancel", schemaVersion: 1)
        await #expect(throws: CancellationError.self) {
            try await setService.set(CancellingCodecSecret(), for: key)
        }

        let raw = KeychainKey(validatedPhysicalAccount: key.account)
        let readService = KeychainServiceSpy(storage: [raw: Data("{}".utf8)])
        await #expect(throws: CancellationError.self) {
            _ = try await readService.value(for: key)
        }
    }

    @Test func preCancelledConveniencesRespectEveryCodecBoundary() async {
        let stringKey = KeychainKey.data("String")
        let codableKey: KeychainCodableKey<FirstSecret> =
            .codable("Codable", schemaVersion: 1)

        let writeService = KeychainServiceSpy()
        let stringWrite = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await writeService.set("value", for: stringKey)
        }
        await #expect(throws: CancellationError.self) { try await stringWrite.value }
        let codableWrite = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await writeService.set(FirstSecret(value: 1), for: codableKey)
        }
        await #expect(throws: CancellationError.self) { try await codableWrite.value }
        #expect(await writeService.callCounts().writes == 0)

        let rawCodable = KeychainKey(validatedPhysicalAccount: codableKey.account)
        let readService = KeychainServiceSpy(storage: [
            stringKey: Data([0xC3, 0x28]),
            rawCodable: Data("not-json".utf8)
        ])
        let stringRead = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            _ = try await readService.string(for: stringKey)
        }
        await #expect(throws: CancellationError.self) { try await stringRead.value }
        let codableRead = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            _ = try await readService.value(for: codableKey)
        }
        await #expect(throws: CancellationError.self) { try await codableRead.value }
        #expect(await readService.callCounts().reads == 2)
    }

    @Test func successfulConvenienceWriteIsNotPostCheckedForCancellation() async throws {
        let service = KeychainServiceSpy(beforeWrite: {
            withUnsafeCurrentTask { $0?.cancel() }
        })
        let stringKey = KeychainKey.data("String")
        let codableKey: KeychainCodableKey<FirstSecret> =
            .codable("Codable", schemaVersion: 1)
        try await Task { try await service.set("value", for: stringKey) }.value
        try await Task {
            try await service.set(FirstSecret(value: 1), for: codableKey)
        }.value
        #expect(await service.callCounts().writes == 2)
    }

    @Test func codableRemoveUsesDerivedRawAccountAndBoolSemantics() async throws {
        let service = KeychainServiceSpy()
        let key: KeychainCodableKey<FirstSecret> = .codable("Session", schemaVersion: 3)
        try await service.set(FirstSecret(value: 1), for: key)
        #expect(try await service.remove(key))
        #expect(!(try await service.remove(key)))
    }

    @Test func realCodecFailuresAreRedactedAtThePublicBoundary() async {
        let encodeService = KeychainServiceSpy()
        let encodeKey: KeychainCodableKey<FailingEncodeSecret> =
            .codable("Encode", schemaVersion: 1)
        do {
            try await encodeService.set(FailingEncodeSecret(), for: encodeKey)
            Issue.record("Expected KeychainServiceError.encodingFailed")
        } catch {
            assertRedacted(
                error,
                expected: .encodingFailed,
                forbidden: ["SECRET-ENCODE-PAYLOAD", "codingPath.session.token"]
            )
        }

        let decodeKey: KeychainCodableKey<FailingDecodeSecret> =
            .codable("Decode", schemaVersion: 1)
        let raw = KeychainKey(validatedPhysicalAccount: decodeKey.account)
        let decodeService = KeychainServiceSpy(storage: [raw: Data("0".utf8)])
        do {
            _ = try await decodeService.value(for: decodeKey)
            Issue.record("Expected KeychainServiceError.decodingFailed")
        } catch {
            assertRedacted(
                error,
                expected: .decodingFailed,
                forbidden: ["SECRET-DECODE-PAYLOAD", "codingPath.session.token"]
            )
        }
    }
}
