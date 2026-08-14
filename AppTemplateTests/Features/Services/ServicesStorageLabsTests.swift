import Foundation
import Testing
@testable import AppTemplate

@MainActor
struct ServicesStorageLabsTests {
    @Test
    func everyDefaultsCodecSupportsSaveReadRemove() throws {
        let service = InMemoryUserDefaultsService(namespace: "Tests.DefaultsLab")
        let model = UserDefaultsLabViewModel(service: service)

        for kind in UserDefaultsLabKind.allCases {
            try model.save(kind)
            #expect(model.actualResult.isSuccess)
            try model.read(kind)
            #expect(model.actualResult.isSuccess)
            model.remove(kind)
            #expect(model.actualResult.isSuccess)
        }
    }

    @Test
    func defaultsCatalogUsesOnlyClosedLogicalNamesAndResetIsSurgical() throws {
        #expect(Set(UserDefaultsLabKind.allCases.map(\.rawValue)) == [
            "bool", "int", "float", "double", "string", "data", "date", "codable"
        ])
        #expect(UserDefaultsLabKeys.allLogicalNames == [
            "Bool", "Int", "Float", "Double", "String", "Data", "Date", "Codable"
        ])

        let service = InMemoryUserDefaultsService(namespace: "Tests.Reset")
        let unrelated = UserDefaultsKey<String>.string("Unrelated")
        try service.set("sentinel", for: unrelated)
        let model = UserDefaultsLabViewModel(service: service)
        for kind in UserDefaultsLabKind.allCases { try model.save(kind) }

        model.resetDemoData()

        #expect(try service.value(for: unrelated) == "sentinel")
        #expect(try service.value(for: UserDefaultsLabKeys.bool) == nil)
        #expect(try service.value(for: UserDefaultsLabKeys.int) == nil)
        #expect(try service.value(for: UserDefaultsLabKeys.float) == nil)
        #expect(try service.value(for: UserDefaultsLabKeys.double) == nil)
        #expect(try service.value(for: UserDefaultsLabKeys.string) == nil)
        #expect(try service.value(for: UserDefaultsLabKeys.data) == nil)
        #expect(try service.value(for: UserDefaultsLabKeys.date) == nil)
        #expect(try service.value(for: UserDefaultsLabKeys.codable) == nil)
    }

    @Test
    func defaultsDataReadRejectsUnboundedPayloadWithoutPublishingBytes() throws {
        let secret = Data(repeating: 0xAB, count: 4_097)
        let service = InMemoryUserDefaultsService(namespace: "Tests.Bounds")
        try service.set(secret, for: UserDefaultsLabKeys.data)
        let model = UserDefaultsLabViewModel(service: service)

        try model.read(.data)

        #expect(!model.actualResult.isSuccess)
        #expect(model.actualResult.message.count < 256)
        #expect(!model.actualResult.message.contains("abab"))
    }

    @Test
    func everyKeychainCodecSupportsSaveReadRemoveAndExplicitReveal() async {
        let service = KeychainServiceSpy()
        let session = StorageLabSessionSpy()
        let model = KeychainLabViewModel(service: service, session: session)

        for kind in KeychainLabKind.allCases {
            await model.save(kind)
            #expect(model.actualResult.isSuccess)
            #expect(!model.isValueRevealed)
            #expect(model.actualResult.message.contains("masked"))

            await model.read(kind)
            #expect(model.actualResult.isSuccess)
            #expect(!model.isValueRevealed)
            #expect(model.actualResult.message.contains("masked"))

            model.revealValue()
            #expect(model.isValueRevealed)
            #expect(!model.actualResult.message.contains("masked"))
            model.hideValue()
            #expect(!model.isValueRevealed)

            await model.remove(kind)
            #expect(model.actualResult.isSuccess)
            #expect(!model.isValueRevealed)
        }
    }

    @Test
    func keychainCatalogAndResetTouchOnlyExactAccountsAndHideValue() async throws {
        #expect(Set(KeychainLabKind.allCases.map(\.rawValue)) == ["data", "string", "codable"])
        #expect(KeychainLabKeys.allPhysicalAccounts == ["Data", "String", "Codable.schema-1"])
        let unrelated = KeychainKey.data("Unrelated")
        let service = KeychainServiceSpy(storage: [unrelated: Data("sentinel".utf8)])
        let model = KeychainLabViewModel(service: service, session: StorageLabSessionSpy())
        for kind in KeychainLabKind.allCases { await model.save(kind) }
        await model.read(.string)
        model.revealValue()

        await model.resetDemoData()

        #expect(!model.isValueRevealed)
        #expect(await service.storedData(for: unrelated) == Data("sentinel".utf8))
        let removals = await service.removals.map(\.account)
        #expect(Set(removals) == KeychainLabKeys.allPhysicalAccounts)
        #expect(removals.count == KeychainLabKeys.allPhysicalAccounts.count)
    }

    @Test
    func keychainDataReadRejectsUnboundedPayloadWithoutPublishingBytes() async {
        let secret = Data(repeating: 0xCD, count: 4_097)
        let service = KeychainServiceSpy(storage: [KeychainLabKeys.data: secret])
        let model = KeychainLabViewModel(service: service, session: StorageLabSessionSpy())

        await model.read(.data)
        model.revealValue()

        #expect(!model.actualResult.isSuccess)
        #expect(model.actualResult.message.count < 256)
        #expect(!model.actualResult.message.contains("cdcd"))
    }

    @Test
    func sessionPanelExposesAtomicStatusAndCallsOnlySemanticActions() async {
        let access = Date(timeIntervalSince1970: 100)
        let refresh = Date(timeIntervalSince1970: 200)
        let status = SessionStatusPresentation(
            session: SessionPresentation(state: .guest, revision: 9),
            expiry: SessionExpiryPresentation(
                accessExpiresAt: access,
                refreshExpiresAt: refresh
            )
        )
        let session = StorageLabSessionSpy(status: status)
        let keychain = KeychainServiceSpy()
        let model = KeychainLabViewModel(service: keychain, session: session)

        #expect(model.sessionStatus == status)
        await model.validateSession()
        await model.refreshSession()

        #expect(session.validateCalls == 1)
        #expect(session.refreshCalls == 1)
        let counts = await keychain.callCounts()
        #expect(counts.reads == 0 && counts.writes == 0 && counts.removals == 0)
    }
}

private extension ServiceLabResult {
    var message: String {
        switch self {
        case .idle, .running: ""
        case let .success(message), let .failure(message): message
        }
    }
}

@MainActor
private final class StorageLabSessionSpy: ISessionActions {
    var status: SessionStatusPresentation
    var presentation: SessionPresentation { status.session }
    private(set) var validateCalls = 0
    private(set) var refreshCalls = 0

    init(status: SessionStatusPresentation = SessionStatusPresentation(
        session: SessionPresentation(state: .guest, revision: 1),
        expiry: nil
    )) {
        self.status = status
    }

    func bootstrap() async {}
    func retryBootstrap() async {}
    func login(username: String, password: String) async -> SessionLoginResult {
        _ = username
        _ = password
        return .cancelled
    }
    func retryPersistence(
        _ token: SessionPersistenceRetryToken
    ) async -> SessionPersistenceRetryResult {
        _ = token
        return .invalidToken
    }
    func discardPersistenceRetry(_ token: SessionPersistenceRetryToken) async { _ = token }
    func validateSession() async -> SessionValidationResult {
        validateCalls += 1
        return .unchanged
    }
    func refreshSession() async -> SessionValidationResult {
        refreshCalls += 1
        return .unchanged
    }
    func signOut() async -> SessionSignOutResult { .cancelled }
}
