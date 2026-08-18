import Foundation
import Security
import Testing
@testable import AppTemplate

@MainActor
struct ServicesLabIsolationTests {
    @Test
    func physicalStoresUseOnlyTheClosedNamespaceAndService() async throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "ServicesLab")
        defer { backing.removePersistentDomain(forName: suiteName) }
        let defaults = UserDefaultsService(
            namespace: "AppTemplate.ServicesLab",
            userDefaults: backing
        )
        let defaultsModel = UserDefaultsLabViewModel(service: defaults)
        for kind in UserDefaultsLabKind.allCases { try defaultsModel.save(kind) }

        let executor = StatefulServicesLabKeychainExecutor()
        let keychain = KeychainService(
            service: "AppTemplate.ServicesLab",
            executor: executor
        )
        let keychainModel = KeychainLabViewModel(
            service: keychain,
            session: IsolationSessionStub()
        )
        for kind in KeychainLabKind.allCases { await keychainModel.save(kind) }

        #expect(backing.storedKeys() == Set(UserDefaultsLabKeys.allLogicalNames.map {
            "AppTemplate.ServicesLab.\($0)"
        }))
        #expect(await executor.services() == ["AppTemplate.ServicesLab"])
        #expect(await executor.accounts(service: "AppTemplate.ServicesLab") == KeychainLabKeys.allPhysicalAccounts)
    }

    @Test
    func everyLabOperationIncludingResetPreservesAllSentinelsByteForByte() async throws {
        let (suiteName, backing) = try makeRecordingUserDefaults(label: "Sentinels")
        defer { backing.removePersistentDomain(forName: suiteName) }
        let defaultsSentinels: [String: Data] = [
            "AppTemplate.AppState": Data([0x01, 0x02]),
            "AppTemplate.Store.CatalogLayout": Data([0x03]),
            "AppTemplate.Store.CatalogSort": Data([0x04]),
            "AppTemplate.Store.RemotePageSize": Data([0x05]),
            "Unrelated.Preference": Data([0x06, 0x07]),
            "AppTemplate.ServicesLab.Unrelated": Data([0x08, 0x09])
        ]
        for (key, value) in defaultsSentinels { backing.seed(value, forKey: key) }
        let defaultsModel = UserDefaultsLabViewModel(service: UserDefaultsService(
            namespace: "AppTemplate.ServicesLab",
            userDefaults: backing
        ))
        for kind in UserDefaultsLabKind.allCases {
            try defaultsModel.save(kind)
            try defaultsModel.read(kind)
            defaultsModel.remove(kind)
            try defaultsModel.save(kind)
        }
        defaultsModel.resetDemoData()

        for (key, value) in defaultsSentinels {
            #expect((backing.rawObject(forKey: key) as? Data) == value)
        }

        let executor = StatefulServicesLabKeychainExecutor(seed: [
            "AppTemplate": ["Store.AuthSession": Data([0x10, 0x11])],
            "Unrelated.Service": ["Record": Data([0x12, 0x13])],
            "AppTemplate.ServicesLab": ["Unrelated": Data([0x14, 0x15])]
        ])
        let keychainModel = KeychainLabViewModel(
            service: KeychainService(
                service: "AppTemplate.ServicesLab",
                executor: executor
            ),
            session: IsolationSessionStub()
        )
        for kind in KeychainLabKind.allCases {
            await keychainModel.save(kind)
            await keychainModel.read(kind)
            await keychainModel.remove(kind)
            await keychainModel.save(kind)
        }
        await keychainModel.resetDemoData()

        #expect(await executor.data(service: "AppTemplate", account: "Store.AuthSession") == Data([0x10, 0x11]))
        #expect(await executor.data(service: "Unrelated.Service", account: "Record") == Data([0x12, 0x13]))
        #expect(await executor.data(service: "AppTemplate.ServicesLab", account: "Unrelated") == Data([0x14, 0x15]))
    }

    @Test
    func nonliveGraphsOwnFreshStoresAndFactoriesReuseTheirOwners() async throws {
        let first = makePreviewGraph()
        let second = makePreviewGraph()
        let firstSliceA = makeServicesSlice(first)
        let firstSliceB = makeServicesSlice(first)
        let secondSlice = makeServicesSlice(second)

        #expect(firstSliceA.userDefaultsLab as AnyObject === first.servicesLabUserDefaults as AnyObject)
        #expect(firstSliceA.keychainLab as AnyObject === first.servicesLabKeychain as AnyObject)
        #expect(firstSliceA.userDefaultsLab as AnyObject === firstSliceB.userDefaultsLab as AnyObject)
        #expect(firstSliceA.keychainLab as AnyObject === firstSliceB.keychainLab as AnyObject)
        #expect(firstSliceA.userDefaultsLab as AnyObject !== secondSlice.userDefaultsLab as AnyObject)
        #expect(firstSliceA.keychainLab as AnyObject !== secondSlice.keychainLab as AnyObject)

        try firstSliceA.userDefaultsLab.set("first", for: UserDefaultsLabKeys.string)
        try await firstSliceA.keychainLab.set("first", for: KeychainLabKeys.string)
        #expect(try secondSlice.userDefaultsLab.value(for: UserDefaultsLabKeys.string) == nil)
        #expect(try await secondSlice.keychainLab.string(for: KeychainLabKeys.string) == nil)
    }

    private func makePreviewGraph() -> AppDependencies {
        AppDependencies.preview(
            appInfo: AppInfoService(displayName: "Storage Lab", version: "1"),
            remoteService: IsolationRemoteStub(),
            diagnostics: NetworkDiagnosticRecorder(),
            images: ImageService.failClosed()
        )
    }

    private func makeServicesSlice(_ dependencies: AppDependencies) -> ServicesDependencies {
        dependencies.makeServicesDependencies(
            appState: AppStateInspector(
                store: AppStateStore(storage: InMemoryAppStateStorage()),
                router: AppFlowRouter(flow: .main)
            ),
            appFlowCoordinator: IsolationFlowCoordinatorStub(),
            sessionActions: IsolationSessionStub(),
            appStateStatus: ServicesAppStateStatus()
        )
    }
}

private actor StatefulServicesLabKeychainExecutor: KeychainSecItemExecuting {
    private var storage: [String: [String: Data]]

    init(seed: [String: [String: Data]] = [:]) { storage = seed }

    func copy(service: String, account: String) async throws -> KeychainSecItemCopyResult {
        guard let data = storage[service]?[account] else { return .status(errSecItemNotFound) }
        return .data(data)
    }

    func update(service: String, account: String, data: Data) async throws -> OSStatus {
        guard storage[service]?[account] != nil else { return errSecItemNotFound }
        storage[service, default: [:]][account] = data
        return errSecSuccess
    }

    func add(service: String, account: String, data: Data) async throws -> OSStatus {
        guard storage[service]?[account] == nil else { return errSecDuplicateItem }
        storage[service, default: [:]][account] = data
        return errSecSuccess
    }

    func delete(service: String, account: String) async throws -> OSStatus {
        guard storage[service]?.removeValue(forKey: account) != nil else {
            return errSecItemNotFound
        }
        return errSecSuccess
    }

    func services() -> Set<String> { Set(storage.keys) }
    func accounts(service: String) -> Set<String> {
        guard let records = storage[service] else { return [] }
        return Set(records.keys)
    }
    func data(service: String, account: String) -> Data? { storage[service]?[account] }
}

private actor IsolationRemoteStub: IRemoteService {
    func products(_ request: ProductPageRequest) async throws -> ProductPageDTO { throw RemoteServiceError.invalidResponse }
    func categories() async throws -> [ProductCategoryDTO] { throw RemoteServiceError.invalidResponse }
    func product(id: Int) async throws -> ProductDTO { throw RemoteServiceError.invalidResponse }
    func login(_ request: LoginRequestDTO) async throws -> AuthSessionDTO { throw RemoteServiceError.invalidResponse }
    func me(accessToken: String) async throws -> UserProfileDTO { throw RemoteServiceError.invalidResponse }
    func refresh(_ request: RefreshRequestDTO) async throws -> AuthTokensDTO { throw RemoteServiceError.invalidResponse }
    func diagnostic(_ request: HTTPDiagnosticRequest) async throws -> HTTPDiagnosticDTO { throw RemoteServiceError.invalidResponse }
}

@MainActor
private final class IsolationFlowCoordinatorStub: IAppFlowCoordinator {
    func completeOnboarding() -> AppFlowActionResult { .unchanged }
    func restartOnboarding() -> AppFlowActionResult { .unchanged }
    func setMaintenanceEnabled(_ enabled: Bool) -> AppFlowActionResult { .unchanged }
}

@MainActor
private final class IsolationSessionStub: ISessionActions {
    var status = SessionStatusPresentation(
        session: SessionPresentation(state: .guest, revision: 1),
        expiry: nil
    )
    var presentation: SessionPresentation { status.session }
    func bootstrap() async {}
    func retryBootstrap() async {}
    func login(username: String, password: String) async -> SessionLoginResult { .cancelled }
    func retryPersistence(_ token: SessionPersistenceRetryToken) async -> SessionPersistenceRetryResult { .invalidToken }
    func discardPersistenceRetry(_ token: SessionPersistenceRetryToken) async {}
    func validateSession() async -> SessionValidationResult { .unchanged }
    func refreshSession() async -> SessionValidationResult { .unchanged }
    func signOut() async -> SessionSignOutResult { .cancelled }
}
