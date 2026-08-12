import Foundation
import Testing
@testable import AppTemplate

@Suite(.serialized)
struct UserDefaultsServiceTests {
    #if os(macOS)
    @Test func blankNamespaceTerminates() async {
        await #expect(processExitsWith: .failure) {
            _ = UserDefaultsService(namespace: " \n\t ")
        }
    }
    #endif

    @Test func missingValueReturnsNil() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "Missing")
        defer { backing.removePersistentDomain(forName: suiteName) }
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)

        #expect(try service.value(for: .bool("Flag")) == nil)
    }

    @Test func nativeLifecycleCoversAllSevenPhysicalTypes() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "Lifecycle")
        defer { backing.removePersistentDomain(forName: suiteName) }
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)

        let boolKey = UserDefaultsKey<Bool>.bool("Bool")
        #expect(try service.value(for: boolKey) == nil)
        try service.set(true, for: boolKey)
        #expect(try service.value(for: boolKey) == true)
        try service.set(false, for: boolKey)
        #expect(try service.value(for: boolKey) == false)
        service.remove(boolKey)
        #expect(try service.value(for: boolKey) == nil)

        let intKey = UserDefaultsKey<Int>.int("Int")
        #expect(try service.value(for: intKey) == nil)
        try service.set(7, for: intKey)
        #expect(try service.value(for: intKey) == 7)
        try service.set(-9, for: intKey)
        #expect(try service.value(for: intKey) == -9)
        service.remove(intKey)
        #expect(try service.value(for: intKey) == nil)

        let floatKey = UserDefaultsKey<Float>.float("Float")
        #expect(try service.value(for: floatKey) == nil)
        try service.set(Float(1.25), for: floatKey)
        #expect(try service.value(for: floatKey) == Float(1.25))
        try service.set(Float(-2.5), for: floatKey)
        #expect(try service.value(for: floatKey) == Float(-2.5))
        service.remove(floatKey)
        #expect(try service.value(for: floatKey) == nil)

        let doubleKey = UserDefaultsKey<Double>.double("Double")
        #expect(try service.value(for: doubleKey) == nil)
        try service.set(Double(1.25), for: doubleKey)
        #expect(try service.value(for: doubleKey) == Double(1.25))
        try service.set(Double(-2.5), for: doubleKey)
        #expect(try service.value(for: doubleKey) == Double(-2.5))
        service.remove(doubleKey)
        #expect(try service.value(for: doubleKey) == nil)

        let stringKey = UserDefaultsKey<String>.string("String")
        #expect(try service.value(for: stringKey) == nil)
        try service.set("first", for: stringKey)
        #expect(try service.value(for: stringKey) == "first")
        try service.set("second", for: stringKey)
        #expect(try service.value(for: stringKey) == "second")
        service.remove(stringKey)
        #expect(try service.value(for: stringKey) == nil)

        let dataKey = UserDefaultsKey<Data>.data("Data")
        #expect(try service.value(for: dataKey) == nil)
        try service.set(Data([0x01, 0x02]), for: dataKey)
        #expect(try service.value(for: dataKey) == Data([0x01, 0x02]))
        try service.set(Data([0x03, 0x04]), for: dataKey)
        #expect(try service.value(for: dataKey) == Data([0x03, 0x04]))
        service.remove(dataKey)
        #expect(try service.value(for: dataKey) == nil)

        let firstDate = Date(timeIntervalSinceReferenceDate: 123)
        let secondDate = Date(timeIntervalSinceReferenceDate: 456)
        let dateKey = UserDefaultsKey<Date>.date("Date")
        #expect(try service.value(for: dateKey) == nil)
        try service.set(firstDate, for: dateKey)
        #expect(try service.value(for: dateKey) == firstDate)
        try service.set(secondDate, for: dateKey)
        #expect(try service.value(for: dateKey) == secondDate)
        service.remove(dateKey)
        #expect(try service.value(for: dateKey) == nil)
    }

    @Test func boolRoundTripsWithBooleanRepresentation() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "Bool")
        defer { backing.removePersistentDomain(forName: suiteName) }
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)

        try service.set(true, for: .bool("Flag"))

        #expect(try service.value(for: .bool("Flag")) == true)
        #expect(backing.physicalKind(forKey: "Tests.Flag") == .bool)
    }

    @Test func intRoundTripsWithNonfloatingNumberRepresentation() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "Int")
        defer { backing.removePersistentDomain(forName: suiteName) }
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)

        try service.set(42, for: .int("Count"))

        #expect(try service.value(for: .int("Count")) == 42)
        #expect(backing.physicalKind(forKey: "Tests.Count") == .int)
    }

    @Test func floatRoundTripsWithFloat32Representation() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "Float")
        defer { backing.removePersistentDomain(forName: suiteName) }
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)

        try service.set(Float(1.25), for: .float("Number"))

        #expect(try service.value(for: .float("Number")) == Float(1.25))
        #expect(backing.physicalKind(forKey: "Tests.Number") == .float32)
    }

    @Test func doubleRoundTripsWithFloat64Representation() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "Double")
        defer { backing.removePersistentDomain(forName: suiteName) }
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)

        try service.set(Double(1.25), for: .double("Number"))

        #expect(try service.value(for: .double("Number")) == Double(1.25))
        #expect(backing.physicalKind(forKey: "Tests.Number") == .float64)
    }

    @Test func stringRoundTrips() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "String")
        defer { backing.removePersistentDomain(forName: suiteName) }
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)

        try service.set("Кыргызча 🌏", for: .string("Name"))

        #expect(try service.value(for: .string("Name")) == "Кыргызча 🌏")
        #expect(backing.physicalKind(forKey: "Tests.Name") == .string)
    }

    @Test func validNamespaceSpellingIsNotTrimmed() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "Namespace")
        defer { backing.removePersistentDomain(forName: suiteName) }
        let service = UserDefaultsService(
            namespace: "  Exact Namespace  ",
            userDefaults: backing
        )

        try service.set(true, for: .bool("Flag"))

        #expect(backing.storedKeys() == ["  Exact Namespace  .Flag"])
    }

    @Test func dataRoundTripsByteForByte() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "Data")
        defer { backing.removePersistentDomain(forName: suiteName) }
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)
        let bytes = Data([0x00, 0xFF, 0x7F, 0x10])

        try service.set(bytes, for: .data("Blob"))

        #expect(try service.value(for: .data("Blob")) == bytes)
        #expect((backing.rawObject(forKey: "Tests.Blob") as? Data) == bytes)
    }

    @Test func dateRoundTrips() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "Date")
        defer { backing.removePersistentDomain(forName: suiteName) }
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)
        let date = Date(timeIntervalSinceReferenceDate: 123_456.75)

        try service.set(date, for: .date("Timestamp"))

        #expect(try service.value(for: .date("Timestamp")) == date)
        #expect(backing.physicalKind(forKey: "Tests.Timestamp") == .date)
    }

    @Test func codableRoundTripsWhileBackingValueIsRawJSONData() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "Codable")
        defer { backing.removePersistentDomain(forName: suiteName) }
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)
        let fixture = CodableFixture(value: 41)

        try service.set(fixture, for: .codable("Fixture"))

        #expect(try service.value(for: .codable("Fixture")) == fixture)
        let bytes = try #require(backing.rawObject(forKey: "Tests.Fixture") as? Data)
        #expect(try JSONDecoder().decode(CodableFixture.self, from: bytes) == fixture)
        #expect(backing.physicalKind(forKey: "Tests.Fixture") == .data)
    }

    @Test func removeMakesValueMissing() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "Remove")
        defer { backing.removePersistentDomain(forName: suiteName) }
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)
        try service.set("value", for: .string("Name"))

        service.remove(.string("Name"))

        #expect(try service.value(for: .string("Name")) == nil)
    }

    @Test func readUsesExactlyOneRawObjectLookup() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "OneRead")
        defer { backing.removePersistentDomain(forName: suiteName) }
        backing.seed("value", forKey: "Tests.Name")
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)

        #expect(try service.value(for: .string("Name")) == "value")

        #expect(backing.objectCallCount == 1)
        #expect(backing.setCallCount == 0)
        #expect(backing.removeCallCount == 0)
    }

    @Test func removeDoesNotReadOrDecode() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "RemoveOnly")
        defer { backing.removePersistentDomain(forName: suiteName) }
        backing.seed(Data([0xFF]), forKey: "Tests.Fixture")
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)

        service.remove(UserDefaultsKey<CodableFixture>.codable("Fixture"))

        #expect(backing.objectCallCount == 0)
        #expect(backing.removeCallCount == 1)
        #expect(backing.rawObject(forKey: "Tests.Fixture") == nil)
    }

    @Test func wrongRepresentationsAreRejectedAndRetained() throws {
        for expected in NativeExpectation.allCases {
            for seed in WrongRepresentationSeed.allCases
            where !seed.matches(expected) {
                let (suiteName, backing) = try makeRecordingUserDefaults(
                    label: "Wrong-\(expected)-\(seed)"
                )
                defer { backing.removePersistentDomain(forName: suiteName) }
                let physicalKey = "Tests.Value"
                seed.seed(backing, key: physicalKey)
                let rawBefore = try #require(backing.rawObject(forKey: physicalKey))
                let kindBefore = try #require(backing.physicalKind(forKey: physicalKey))
                let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)

                expectUserDefaultsServiceError(.invalidStoredValue) {
                    try expected.read(service, logicalName: "Value")
                }

                let rawAfter = try #require(backing.rawObject(forKey: physicalKey))
                #expect(userDefaultsTestObjectsAreEqual(rawBefore, rawAfter))
                #expect(backing.physicalKind(forKey: physicalKey) == kindBefore)
                #expect(backing.setCallCount == 0)
                #expect(backing.removeCallCount == 0)
            }
        }
    }

    @Test func urlOriginDataIsAcceptedByDataKey() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "URLData")
        defer { backing.removePersistentDomain(forName: suiteName) }
        let url = try #require(URL(string: "https://example.invalid/path"))
        backing.seed(url, forKey: "Tests.Blob")
        let normalized = try #require(backing.rawObject(forKey: "Tests.Blob") as? Data)
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)

        #expect(try service.value(for: .data("Blob")) == normalized)
        #expect((backing.rawObject(forKey: "Tests.Blob") as? Data) == normalized)
    }

    @Test func urlOriginDataReachesCodableDecoderAndRemainsUntouched() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "URLCodable")
        defer { backing.removePersistentDomain(forName: suiteName) }
        let url = try #require(URL(string: "https://example.invalid/path"))
        backing.seed(url, forKey: "Tests.Fixture")
        let normalized = try #require(backing.rawObject(forKey: "Tests.Fixture") as? Data)
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)

        expectUserDefaultsServiceError(.decodingFailed) {
            _ = try service.value(for: UserDefaultsKey<CodableFixture>.codable("Fixture"))
        }

        #expect((backing.rawObject(forKey: "Tests.Fixture") as? Data) == normalized)
        #expect(backing.removeCallCount == 0)
        #expect(backing.setCallCount == 0)
    }

    @Test func booleanIsNeverAcceptedAsInt() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "BoolNotInt")
        defer { backing.removePersistentDomain(forName: suiteName) }
        backing.seed(true, forKey: "Tests.Value")
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)

        expectUserDefaultsServiceError(.invalidStoredValue) {
            _ = try service.value(for: UserDefaultsKey<Int>.int("Value"))
        }
        #expect(backing.physicalKind(forKey: "Tests.Value") == .bool)
    }

    @Test func integerIsNeverAcceptedAsBool() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "IntNotBool")
        defer { backing.removePersistentDomain(forName: suiteName) }
        backing.seed(1, forKey: "Tests.Value")
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)

        expectUserDefaultsServiceError(.invalidStoredValue) {
            _ = try service.value(for: UserDefaultsKey<Bool>.bool("Value"))
        }
        #expect(backing.physicalKind(forKey: "Tests.Value") == .int)
    }

    @Test func floatIsNeverAcceptedAsDouble() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "FloatNotDouble")
        defer { backing.removePersistentDomain(forName: suiteName) }
        backing.seed(Float(1.25), forKey: "Tests.Value")
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)

        expectUserDefaultsServiceError(.invalidStoredValue) {
            _ = try service.value(for: UserDefaultsKey<Double>.double("Value"))
        }
        #expect(backing.physicalKind(forKey: "Tests.Value") == .float32)
    }

    @Test func doubleIsNeverAcceptedAsFloat() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "DoubleNotFloat")
        defer { backing.removePersistentDomain(forName: suiteName) }
        backing.seed(Double(1.25), forKey: "Tests.Value")
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)

        expectUserDefaultsServiceError(.invalidStoredValue) {
            _ = try service.value(for: UserDefaultsKey<Float>.float("Value"))
        }
        #expect(backing.physicalKind(forKey: "Tests.Value") == .float64)
    }

    @Test func floatingNumberIsNeverAcceptedAsInt() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "FloatNotInt")
        defer { backing.removePersistentDomain(forName: suiteName) }
        backing.seed(Double(7), forKey: "Tests.Value")
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)

        expectUserDefaultsServiceError(.invalidStoredValue) {
            _ = try service.value(for: UserDefaultsKey<Int>.int("Value"))
        }
        #expect(backing.physicalKind(forKey: "Tests.Value") == .float64)
    }

    @Test func outOfRangeIntegerIsRejected() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "OutOfRange")
        defer { backing.removePersistentDomain(forName: suiteName) }
        backing.seed(NSNumber(value: UInt64.max), forKey: "Tests.Value")
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)

        expectUserDefaultsServiceError(.invalidStoredValue) {
            _ = try service.value(for: UserDefaultsKey<Int>.int("Value"))
        }

        #expect(backing.physicalKind(forKey: "Tests.Value") == .int)
        #expect(
            userDefaultsTestObjectsAreEqual(
                backing.rawObject(forKey: "Tests.Value"),
                NSNumber(value: UInt64.max)
            )
        )
    }

    @Test func outOfRangeIntegerToIntReplacementRemovesOldRepresentation() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "OutOfRangeReplacement")
        defer { backing.removePersistentDomain(forName: suiteName) }
        backing.seed(NSNumber(value: UInt64.max), forKey: "Tests.Value")
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)

        try service.set(7, for: .int("Value"))

        #expect(try service.value(for: .int("Value")) == 7)
        #expect(backing.removeCallCount == 1)
        #expect(backing.physicalKind(forKey: "Tests.Value") == .int)
    }

    @Test func stringToDataReplacementRemovesOldRepresentation() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "StringData")
        defer { backing.removePersistentDomain(forName: suiteName) }
        backing.seed("old", forKey: "Tests.Value")
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)
        let bytes = Data([0x01, 0x02])

        try service.set(bytes, for: .data("Value"))

        #expect(try service.value(for: .data("Value")) == bytes)
        #expect(backing.removeCallCount == 1)
        #expect(backing.physicalKind(forKey: "Tests.Value") == .data)
    }

    @Test func equalBoolToIntReplacementRemovesOldRepresentation() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "BoolInt")
        defer { backing.removePersistentDomain(forName: suiteName) }
        backing.seed(true, forKey: "Tests.Number")
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)

        try service.set(1, for: .int("Number"))

        #expect(try service.value(for: .int("Number")) == 1)
        #expect(backing.removeCallCount == 1)
        #expect(backing.physicalKind(forKey: "Tests.Number") == .int)
    }

    @Test func equalIntToBoolReplacementRemovesOldRepresentation() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "IntBool")
        defer { backing.removePersistentDomain(forName: suiteName) }
        backing.seed(1, forKey: "Tests.Number")
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)

        try service.set(true, for: .bool("Number"))

        #expect(try service.value(for: .bool("Number")) == true)
        #expect(backing.removeCallCount == 1)
        #expect(backing.physicalKind(forKey: "Tests.Number") == .bool)
    }

    @Test func equalFloatToDoubleReplacementRemovesOldRepresentation() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "FloatDouble")
        defer { backing.removePersistentDomain(forName: suiteName) }
        backing.seed(Float(1.25), forKey: "Tests.Number")
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)

        try service.set(Double(1.25), for: .double("Number"))

        #expect(try service.value(for: .double("Number")) == Double(1.25))
        #expect(backing.removeCallCount == 1)
        #expect(backing.physicalKind(forKey: "Tests.Number") == .float64)
    }

    @Test func equalDoubleToFloatReplacementRemovesOldRepresentation() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "DoubleFloat")
        defer { backing.removePersistentDomain(forName: suiteName) }
        backing.seed(Double(1.25), forKey: "Tests.Number")
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)

        try service.set(Float(1.25), for: .float("Number"))

        #expect(try service.value(for: .float("Number")) == Float(1.25))
        #expect(backing.removeCallCount == 1)
        #expect(backing.physicalKind(forKey: "Tests.Number") == .float32)
    }

    @Test func equalIntToDoubleReplacementRemovesOldRepresentation() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "IntDouble")
        defer { backing.removePersistentDomain(forName: suiteName) }
        backing.seed(1, forKey: "Tests.Number")
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)

        try service.set(Double(1), for: .double("Number"))

        #expect(try service.value(for: .double("Number")) == Double(1))
        #expect(backing.removeCallCount == 1)
        #expect(backing.physicalKind(forKey: "Tests.Number") == .float64)
    }

    @Test func equalDoubleToIntReplacementRemovesOldRepresentation() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "DoubleInt")
        defer { backing.removePersistentDomain(forName: suiteName) }
        backing.seed(Double(1), forKey: "Tests.Number")
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)

        try service.set(1, for: .int("Number"))

        #expect(try service.value(for: .int("Number")) == 1)
        #expect(backing.removeCallCount == 1)
        #expect(backing.physicalKind(forKey: "Tests.Number") == .int)
    }

    @Test func sameKindReplacementDoesNotRemoveFirst() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "SameKind")
        defer { backing.removePersistentDomain(forName: suiteName) }
        backing.seed(Double(1.25), forKey: "Tests.Number")
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)

        try service.set(Double(2.5), for: .double("Number"))

        #expect(try service.value(for: .double("Number")) == Double(2.5))
        #expect(backing.removeCallCount == 0)
        #expect(backing.physicalKind(forKey: "Tests.Number") == .float64)
    }

    @Test func encodingFailureLeavesExistingBytesUntouched() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "EncodingRetains")
        defer { backing.removePersistentDomain(forName: suiteName) }
        let oldBytes = Data([0x01, 0x02, 0x03])
        backing.seed(oldBytes, forKey: "Tests.Fixture")
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)

        expectUserDefaultsServiceError(.encodingFailed) {
            try service.set(
                ThrowingCodable(value: 7),
                for: UserDefaultsKey<ThrowingCodable>.codable("Fixture")
            )
        }

        #expect((backing.rawObject(forKey: "Tests.Fixture") as? Data) == oldBytes)
        #expect(backing.removeCallCount == 0)
        #expect(backing.setCallCount == 0)
    }

    @Test func encodingFailurePerformsNoRawAccess() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "EncodingNoRaw")
        defer { backing.removePersistentDomain(forName: suiteName) }
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)

        expectUserDefaultsServiceError(.encodingFailed) {
            try service.set(
                ThrowingCodable(value: 7),
                for: UserDefaultsKey<ThrowingCodable>.codable("Fixture")
            )
        }

        #expect(backing.objectCallCount == 0)
        #expect(backing.setCallCount == 0)
        #expect(backing.removeCallCount == 0)
    }

    @Test func malformedCodableDataThrowsDecodingFailedAndRemainsUntouched() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "Malformed")
        defer { backing.removePersistentDomain(forName: suiteName) }
        let malformed = Data([0xFF, 0x00, 0xFE])
        backing.seed(malformed, forKey: "Tests.Fixture")
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)

        expectUserDefaultsServiceError(.decodingFailed) {
            _ = try service.value(for: UserDefaultsKey<CodableFixture>.codable("Fixture"))
        }

        #expect((backing.rawObject(forKey: "Tests.Fixture") as? Data) == malformed)
        #expect(backing.removeCallCount == 0)
        #expect(backing.setCallCount == 0)
    }

    @Test(.timeLimit(.minutes(1)))
    func codableEncodingCanReenterTheSameService() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "EncodeReentrant")
        defer { backing.removePersistentDomain(forName: suiteName) }
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)
        let fixture = ReentrantEncodingFixture(value: 7) {
            try service.set(true, for: .bool("Reentered"))
        }

        try service.set(fixture, for: .codable("Outer"))

        #expect(try service.value(for: .bool("Reentered")) == true)
        #expect(
            try service.value(
                for: UserDefaultsKey<ReentrantEncodingFixture>.codable("Outer")
            )?.value == 7
        )
    }

    @Test(.timeLimit(.minutes(1)))
    func codableDecodingCanReenterTheSameService() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "DecodeReentrant")
        defer { backing.removePersistentDomain(forName: suiteName) }
        defer { ReentrantDecodingFixtureCallback.reset() }
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)
        try service.set(
            ReentrantDecodingFixture(value: 9),
            for: .codable("Outer")
        )
        ReentrantDecodingFixtureCallback.install {
            try service.set(true, for: .bool("Reentered"))
        }

        let decoded = try service.value(
            for: UserDefaultsKey<ReentrantDecodingFixture>.codable("Outer")
        )

        #expect(decoded == ReentrantDecodingFixture(value: 9))
        #expect(try service.value(for: .bool("Reentered")) == true)
    }

    @Test func concurrentCallsThroughOneServiceRemainValid() async throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "Concurrent")
        defer { backing.removePersistentDomain(forName: suiteName) }
        backing.enableRawCallOverlapDelay()
        let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<100 {
                group.addTask {
                    let key = UserDefaultsKey<Int>.int("Concurrent-\(index)")
                    try service.set(index, for: key)
                    guard try service.value(for: key) == index else {
                        throw UserDefaultsConcurrentTestError.wrongValue
                    }
                }
            }
            try await group.waitForAll()
        }

        #expect(backing.maxConcurrentRawCalls == 1)
    }

    @Test func serviceErrorsArePayloadFree() throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "Errors")
        defer { backing.removePersistentDomain(forName: suiteName) }
        let namespace = "NAMESPACE-SENTINEL"
        let service = UserDefaultsService(namespace: namespace, userDefaults: backing)
        backing.seed("VALUE-SENTINEL", forKey: "\(namespace).INVALID-KEY-SENTINEL")
        backing.seed(
            Data("MALFORMED-BYTES-SENTINEL".utf8),
            forKey: "\(namespace).DECODING-KEY-SENTINEL"
        )

        let invalid = captureUserDefaultsServiceError {
            _ = try service.value(
                for: UserDefaultsKey<Bool>.bool("INVALID-KEY-SENTINEL")
            )
        }
        let encoding = captureUserDefaultsServiceError {
            try service.set(
                ThrowingCodable(value: 7),
                for: UserDefaultsKey<ThrowingCodable>.codable(
                    "ENCODING-KEY-SENTINEL"
                )
            )
        }
        let decoding = captureUserDefaultsServiceError {
            _ = try service.value(
                for: UserDefaultsKey<CodableFixture>.codable(
                    "DECODING-KEY-SENTINEL"
                )
            )
        }

        #expect(invalid == .invalidStoredValue)
        #expect(encoding == .encodingFailed)
        #expect(decoding == .decodingFailed)
        let sentinels = [
            "NAMESPACE-SENTINEL",
            "INVALID-KEY-SENTINEL",
            "ENCODING-KEY-SENTINEL",
            "DECODING-KEY-SENTINEL",
            "VALUE-SENTINEL",
            "MALFORMED-BYTES-SENTINEL",
            "UNDERLYING-ENCODING-SENTINEL",
            "codingPath"
        ]
        for error in [invalid, encoding, decoding] {
            for description in [
                String(describing: error),
                String(reflecting: error),
                (error as NSError).localizedDescription
            ] {
                for sentinel in sentinels {
                    #expect(!description.contains(sentinel))
                }
            }
        }
    }
}

nonisolated
private enum NativeExpectation: CaseIterable, Sendable {
    case bool, int, float, double, string, data, date

    func read(_ service: UserDefaultsService, logicalName: String) throws {
        switch self {
        case .bool:
            _ = try service.value(for: UserDefaultsKey<Bool>.bool(logicalName))
        case .int:
            _ = try service.value(for: UserDefaultsKey<Int>.int(logicalName))
        case .float:
            _ = try service.value(for: UserDefaultsKey<Float>.float(logicalName))
        case .double:
            _ = try service.value(for: UserDefaultsKey<Double>.double(logicalName))
        case .string:
            _ = try service.value(for: UserDefaultsKey<String>.string(logicalName))
        case .data:
            _ = try service.value(for: UserDefaultsKey<Data>.data(logicalName))
        case .date:
            _ = try service.value(for: UserDefaultsKey<Date>.date(logicalName))
        }
    }
}

nonisolated
private enum WrongRepresentationSeed: CaseIterable, Sendable {
    case bool, int, float, double, string, data, date, array, dictionary

    func matches(_ expected: NativeExpectation) -> Bool {
        switch (self, expected) {
        case (.bool, .bool), (.int, .int), (.float, .float),
             (.double, .double), (.string, .string), (.data, .data),
             (.date, .date):
            true
        default:
            false
        }
    }

    func seed(_ backing: RecordingUserDefaults, key: String) {
        switch self {
        case .bool:
            backing.seed(true, forKey: key)
        case .int:
            backing.seed(7, forKey: key)
        case .float:
            backing.seed(Float(1.25), forKey: key)
        case .double:
            backing.seed(Double(1.25), forKey: key)
        case .string:
            backing.seed("wrong", forKey: key)
        case .data:
            backing.seed(Data([0x01, 0x02]), forKey: key)
        case .date:
            backing.seed(Date(timeIntervalSinceReferenceDate: 123), forKey: key)
        case .array:
            backing.seed(["wrong"], forKey: key)
        case .dictionary:
            backing.seed(["wrong": "value"], forKey: key)
        }
    }
}

nonisolated
private enum UserDefaultsConcurrentTestError: Error, Sendable {
    case wrongValue
}

nonisolated
private func expectUserDefaultsServiceError(
    _ expected: UserDefaultsServiceError,
    _ operation: () throws -> Void
) {
    do {
        try operation()
        Issue.record("Expected UserDefaultsServiceError.\(expected)")
    } catch let error as UserDefaultsServiceError {
        #expect(error == expected)
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

nonisolated
private func captureUserDefaultsServiceError(
    _ operation: () throws -> Void
) -> UserDefaultsServiceError {
    do {
        try operation()
        Issue.record("Expected UserDefaultsServiceError")
        return .invalidStoredValue
    } catch let error as UserDefaultsServiceError {
        return error
    } catch {
        Issue.record("Unexpected error: \(error)")
        return .invalidStoredValue
    }
}
