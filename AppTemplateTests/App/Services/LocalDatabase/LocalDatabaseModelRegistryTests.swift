import SwiftData
import Testing
@testable import AppTemplate

struct LocalDatabaseModelRegistryTests {
    @Test
    func testRegistryAcceptsExampleAndTestRegistrationsAsBijection() throws {
        let registry = makeGenericTestRegistry()
        try registry.validateIntegrity()
        #expect(registry.registrationCount == 2)
        #expect(registry.contains(ExampleRecordAdapter.self))
        #expect(registry.contains(TestLocalRecordAdapter.self))
        #expect(registry.registeredEntityIdentifiers.count == 2)
    }

    @Test
    func productionRegistryContainsExactlyExampleRegistration() throws {
        let registry = LocalDatabaseModelRegistry.production

        try registry.validateIntegrity()
        #expect(registry.registrationCount == 1)
        #expect(registry.contains(ExampleRecordAdapter.self))
        #expect(
            registry.registeredEntityIdentifiers
                == [ObjectIdentifier(
                    LocalDatabaseSchemaV1.StoredExampleRecord.self
                )]
        )
    }

    @Test
    func productionRegistryEntityTypesEqualFrozenSchemaTypesAndCardinality() throws {
        let registry = LocalDatabaseModelRegistry.production
        let schemaIdentifiers = Set(
            LocalDatabaseSchemaV1.models.map(ObjectIdentifier.init)
        )

        try registry.validateIntegrity()
        #expect(registry.registrationCount == schemaIdentifiers.count)
        #expect(registry.registeredEntityIdentifiers == schemaIdentifiers)
    }

    @Test(arguments: RegistryCollisionFixture.allCases)
    func duplicateIdentityIsRejectedWithoutTrapping(
        fixture: RegistryCollisionFixture
    ) {
        #expect(
            LocalDatabaseRegistrationIdentityValidator
                .firstIntegrityError(in: fixture.identities)
                == fixture.expectedError
        )
    }

    @Test
    func integrityFailureUsesAdapterValueEntityNamePriority() {
        let identity = LocalDatabaseRegistrationIdentity(
            adapterIdentifier: ObjectIdentifier(IdentityA.self),
            valueIdentifier: ObjectIdentifier(IdentityB.self),
            entityIdentifier: ObjectIdentifier(IdentityC.self),
            diagnosticName: "duplicate"
        )
        #expect(
            LocalDatabaseRegistrationIdentityValidator
                .firstIntegrityError(in: [identity, identity])
                == .duplicateAdapter
        )
    }

    @Test
    func integrityFailurePrioritizesAdapterAcrossCompetingCollisions() {
        let identities = [
            LocalDatabaseRegistrationIdentity(
                adapterIdentifier: ObjectIdentifier(IdentityA.self),
                valueIdentifier: ObjectIdentifier(IdentityB.self),
                entityIdentifier: ObjectIdentifier(IdentityC.self),
                diagnosticName: "shared"
            ),
            LocalDatabaseRegistrationIdentity(
                adapterIdentifier: ObjectIdentifier(IdentityD.self),
                valueIdentifier: ObjectIdentifier(IdentityE.self),
                entityIdentifier: ObjectIdentifier(IdentityF.self),
                diagnosticName: "shared"
            ),
            LocalDatabaseRegistrationIdentity(
                adapterIdentifier: ObjectIdentifier(IdentityA.self),
                valueIdentifier: ObjectIdentifier(IdentityG.self),
                entityIdentifier: ObjectIdentifier(IdentityH.self),
                diagnosticName: "unique"
            )
        ]

        #expect(
            LocalDatabaseRegistrationIdentityValidator
                .firstIntegrityError(in: identities)
                == .duplicateAdapter
        )
    }

    @Test
    func invalidRegistryReportsDuplicateAdapter() {
        let registry = LocalDatabaseModelRegistry(
            adapters: [ExampleRecordAdapter.self, ExampleRecordAdapter.self]
        )

        do {
            try registry.validateIntegrity()
            Issue.record("Expected duplicate adapter registry to fail")
        } catch let error as LocalDatabaseModelRegistryError {
            #expect(error == .duplicateAdapter)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

nonisolated
enum RegistryCollisionFixture: CaseIterable, CustomTestStringConvertible, Sendable {
    case adapter
    case value
    case entity
    case diagnosticName

    var testDescription: String { String(describing: self) }

    var identities: [LocalDatabaseRegistrationIdentity] {
        let first = LocalDatabaseRegistrationIdentity(
            adapterIdentifier: ObjectIdentifier(IdentityA.self),
            valueIdentifier: ObjectIdentifier(IdentityB.self),
            entityIdentifier: ObjectIdentifier(IdentityC.self),
            diagnosticName: "IdentityD"
        )

        let second: LocalDatabaseRegistrationIdentity
        switch self {
        case .adapter:
            second = LocalDatabaseRegistrationIdentity(
                adapterIdentifier: ObjectIdentifier(IdentityA.self),
                valueIdentifier: ObjectIdentifier(IdentityE.self),
                entityIdentifier: ObjectIdentifier(IdentityF.self),
                diagnosticName: "IdentityG"
            )
        case .value:
            second = LocalDatabaseRegistrationIdentity(
                adapterIdentifier: ObjectIdentifier(IdentityD.self),
                valueIdentifier: ObjectIdentifier(IdentityB.self),
                entityIdentifier: ObjectIdentifier(IdentityF.self),
                diagnosticName: "IdentityG"
            )
        case .entity:
            second = LocalDatabaseRegistrationIdentity(
                adapterIdentifier: ObjectIdentifier(IdentityD.self),
                valueIdentifier: ObjectIdentifier(IdentityE.self),
                entityIdentifier: ObjectIdentifier(IdentityC.self),
                diagnosticName: "IdentityG"
            )
        case .diagnosticName:
            second = LocalDatabaseRegistrationIdentity(
                adapterIdentifier: ObjectIdentifier(IdentityD.self),
                valueIdentifier: ObjectIdentifier(IdentityE.self),
                entityIdentifier: ObjectIdentifier(IdentityF.self),
                diagnosticName: "IdentityD"
            )
        }

        return [first, second]
    }

    var expectedError: LocalDatabaseModelRegistryError {
        switch self {
        case .adapter:
            .duplicateAdapter
        case .value:
            .duplicateValue
        case .entity:
            .duplicateEntity
        case .diagnosticName:
            .duplicateDiagnosticName
        }
    }
}

nonisolated private enum IdentityA {}
nonisolated private enum IdentityB {}
nonisolated private enum IdentityC {}
nonisolated private enum IdentityD {}
nonisolated private enum IdentityE {}
nonisolated private enum IdentityF {}
nonisolated private enum IdentityG {}
nonisolated private enum IdentityH {}
