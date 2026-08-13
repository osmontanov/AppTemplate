nonisolated
enum LocalDatabaseModelRegistryError: Error, Equatable, Sendable {
    case duplicateAdapter
    case duplicateValue
    case duplicateEntity
    case duplicateDiagnosticName
}

nonisolated
struct LocalDatabaseRegistrationIdentity: Equatable, Sendable {
    let adapterIdentifier: ObjectIdentifier
    let valueIdentifier: ObjectIdentifier
    let entityIdentifier: ObjectIdentifier
    let diagnosticName: String
}

nonisolated
struct LocalDatabaseModelRegistry: Sendable {
    private let adapters: [any LocalEntityAdapter.Type]
    private let integrityError: LocalDatabaseModelRegistryError?
    private let adapterIdentifiers: Set<ObjectIdentifier>

    let registrationCount: Int
    let registeredEntityIdentifiers: Set<ObjectIdentifier>

    init(adapters: [any LocalEntityAdapter.Type]) {
        self.adapters = adapters
        let identities = adapters.map {
            LocalDatabaseRegistrationIdentity(
                adapterIdentifier: $0.adapterIdentifier,
                valueIdentifier: $0.valueIdentifier,
                entityIdentifier: $0.entityIdentifier,
                diagnosticName: $0.diagnosticName
            )
        }
        integrityError = LocalDatabaseRegistrationIdentityValidator
            .firstIntegrityError(in: identities)
        adapterIdentifiers = Set(
            identities.map(\.adapterIdentifier)
        )
        registeredEntityIdentifiers = Set(
            identities.map(\.entityIdentifier)
        )
        registrationCount = identities.count
    }

    static let production = LocalDatabaseModelRegistry(
        adapters: [
            ExampleRecordAdapter.self,
            FavoriteProductSnapshotAdapter.self,
            CartAggregateAdapter.self
        ]
    )

    func validateIntegrity() throws {
        if let integrityError { throw integrityError }
    }

    func contains<Adapter: LocalEntityAdapter>(
        _ adapter: Adapter.Type
    ) -> Bool {
        adapterIdentifiers.contains(adapter.adapterIdentifier)
    }
}

nonisolated
enum LocalDatabaseRegistrationIdentityValidator {
    static func firstIntegrityError(
        in identities: [LocalDatabaseRegistrationIdentity]
    ) -> LocalDatabaseModelRegistryError? {
        guard Set(identities.map(\.adapterIdentifier)).count
            == identities.count
        else { return .duplicateAdapter }
        guard Set(identities.map(\.valueIdentifier)).count
            == identities.count
        else { return .duplicateValue }
        guard Set(identities.map(\.entityIdentifier)).count
            == identities.count
        else { return .duplicateEntity }
        guard Set(identities.map(\.diagnosticName)).count
            == identities.count
        else { return .duplicateDiagnosticName }
        return nil
    }
}
