import Foundation
import Testing
@testable import AppTemplate

@MainActor
struct ServicesDatabaseRemoteLabsTests {
    @Test
    func localDatabaseOperationMatrixUsesOnlyTheExampleRepositoryFacade() async {
        let repository = DatabaseLabRepositorySpy()
        let model = LocalDatabaseLabViewModel(repository: repository, pageSize: 2)

        model.draftID = "demo-alpha"
        model.draftPayload = "Alpha"
        await model.fetchByID()
        #expect(await repository.calls == [.fetch("demo-alpha")])

        await repository.clearCalls()
        await model.createDraft()
        #expect(await repository.calls == [
            .create(ExampleRecord(id: "demo-alpha", payload: "Alpha")),
            .page(search: nil, afterID: nil, pageSize: 2)
        ])

        await repository.clearCalls()
        model.draftPayload = "Updated"
        await model.updateDraft()
        #expect(await repository.calls == [
            .update(ExampleRecord(id: "demo-alpha", payload: "Updated")),
            .page(search: nil, afterID: nil, pageSize: 2)
        ])

        await repository.clearCalls()
        model.draftID = "inserted"
        await model.upsertDraft()
        model.draftPayload = "Replacement"
        await model.upsertDraft()
        #expect(await repository.calls == [
            .upsert(ExampleRecord(id: "inserted", payload: "Updated")),
            .page(search: nil, afterID: nil, pageSize: 2),
            .upsert(ExampleRecord(id: "inserted", payload: "Replacement")),
            .page(search: nil, afterID: nil, pageSize: 2)
        ])

        await repository.clearCalls()
        model.batchDrafts = [
            ExampleRecord(id: "batch-a", payload: "A"),
            ExampleRecord(id: "batch-b", payload: "B")
        ]
        await model.upsertBatch()
        #expect(await repository.calls == [
            .upsertBatch(model.batchDrafts),
            .page(search: nil, afterID: nil, pageSize: 2)
        ])

        await repository.clearCalls()
        model.searchText = "needle"
        await model.refresh()
        #expect(await repository.calls == [
            .page(search: "needle", afterID: nil, pageSize: 2)
        ])

        await repository.setPage(
            values: [ExampleRecord(id: "a", payload: "A")],
            nextCursor: "a",
            hasMore: true
        )
        model.searchText = ""
        await model.refresh()
        await repository.setPage(
            values: [ExampleRecord(id: "b", payload: "B")],
            nextCursor: nil,
            hasMore: false
        )
        await model.loadMore()
        #expect(model.state.records.map(\.id) == ["a", "b"])

        await repository.clearCalls()
        model.draftID = "a"
        await model.deleteByID()
        #expect(await repository.calls == [
            .delete("a"),
            .page(search: nil, afterID: nil, pageSize: 2)
        ])

        await repository.clearCalls()
        await model.deleteAllConfirmed()
        #expect(await repository.calls == [
            .deleteAll,
            .page(search: nil, afterID: nil, pageSize: 2)
        ])

        await repository.clearCalls()
        await model.resetDemoData()
        let resetCalls = await repository.calls
        #expect(resetCalls.first == .deleteAll)
        #expect(resetCalls.dropFirst().first?.isThreeRecordBatch == true)
        #expect(resetCalls.last == .page(search: nil, afterID: nil, pageSize: 2))
    }

    @Test
    func mutationResetsCursorBeforeReload() async {
        let repository = DatabaseLabRepositorySpy()
        let model = LocalDatabaseLabViewModel(repository: repository, pageSize: 1)
        await repository.setPage(
            values: [ExampleRecord(id: "a", payload: "A")],
            nextCursor: "a",
            hasMore: true
        )
        await model.refresh()
        await repository.setPage(values: [], nextCursor: nil, hasMore: false)
        await model.loadMore()
        model.draftID = "created"
        model.draftPayload = "value"
        await model.createDraft()

        #expect(await repository.requestedCursors == [nil, "a", nil])
    }

    @Test
    func pageSizeAcceptsEveryValueInTheContractAndRejectsOutsideWithoutMutation() async {
        for pageSize in 1...50 {
            let repository = DatabaseLabRepositorySpy()
            let model = LocalDatabaseLabViewModel(repository: repository)
            await model.setPageSize(pageSize)
            #expect(model.state.pageSize == pageSize)
            #expect(await repository.calls == [
                .page(search: nil, afterID: nil, pageSize: pageSize)
            ])
        }

        for invalid in [0, 51] {
            let repository = DatabaseLabRepositorySpy()
            let model = LocalDatabaseLabViewModel(repository: repository)
            let original = model.state
            await model.setPageSize(invalid)
            #expect(model.state == original)
            #expect(await repository.calls.isEmpty)
            #expect(model.lastRetryOperation == nil)
        }
    }

    @Test
    func latestDatabaseFailureStoresABoundedDescriptorAndRetryRunsItOnce() async {
        let repository = DatabaseLabRepositorySpy()
        let model = LocalDatabaseLabViewModel(repository: repository)
        model.draftID = "first"
        model.draftPayload = "one"
        await repository.failNext()
        await model.createDraft()
        #expect(model.lastRetryOperation == .create(
            ExampleRecord(id: "first", payload: "one")
        ))

        model.draftID = "second"
        model.draftPayload = "two"
        await repository.failNext()
        await model.deleteByID()
        #expect(model.lastRetryOperation == .delete("second"))

        await repository.clearCalls()
        await model.retryLastOperation()
        #expect(await repository.calls == [
            .delete("second"),
            .page(search: nil, afterID: nil, pageSize: 20)
        ])
        #expect(model.lastRetryOperation == nil)
        #expect(model.actualResult.isSuccess)
    }

    @Test
    func postMutationReloadFailureRetriesOnlyTheFirstPageAndPreservesPresentation() async {
        let repository = DatabaseLabRepositorySpy()
        await repository.setPage(
            values: [ExampleRecord(id: "visible", payload: "Visible")],
            nextCursor: "visible",
            hasMore: true
        )
        let model = LocalDatabaseLabViewModel(repository: repository, pageSize: 1)
        await model.refresh()
        let presentedState = model.state
        model.draftID = "created"
        model.draftPayload = "Created"
        await repository.failNextPage()

        await model.createDraft()

        #expect(model.state == presentedState)
        #expect(model.lastRetryOperation == .page(
            search: nil, afterID: nil, pageSize: 1
        ))
        await repository.clearCalls()
        await repository.setPage(values: [], nextCursor: nil, hasMore: false)
        await model.retryLastOperation()
        #expect(await repository.calls == [
            .page(search: nil, afterID: nil, pageSize: 1)
        ])
    }

    @Test
    func invalidDatabaseDraftNeverCallsOrBecomesRetryable() async {
        let repository = DatabaseLabRepositorySpy()
        let model = LocalDatabaseLabViewModel(repository: repository)
        model.draftID = String(repeating: "x", count: 129)
        model.draftPayload = "value"

        await model.createDraft()

        #expect(await repository.calls.isEmpty)
        #expect(model.lastRetryOperation == nil)
        #expect(!model.actualResult.isSuccess)
    }

    @Test
    func remoteFacadeForwardsOnlyTheFourTokenFreeBoundaries() async throws {
        let remote = RemoteServiceBoundarySpy()
        let facade: any IRemoteAPILabService = RemoteAPILabService(remote: remote)
        let request = ProductPageRequest(mode: .search("phone"), sort: nil, limit: 10, skip: 0)

        _ = try await facade.products(request)
        _ = try await facade.categories()
        _ = try await facade.product(id: 7)
        _ = try await facade.diagnostic(.status(code: 404))

        #expect(await remote.calls == [
            .products(request), .categories, .product(7), .diagnostic(.status(code: 404))
        ])
        #expect(await remote.authenticationCallCount == 0)
    }

    @Test
    func remoteOperationMatrixCoversPagingSearchCategoriesCategoryDetailAndDiagnostics() async {
        let remote = RemoteLabServiceSpy()
        let session = RemoteLabSessionSpy()
        let recorder = NetworkDiagnosticRecorder(capacity: 4)
        let model = RemoteAPILabViewModel(remote: remote, session: session, diagnostics: recorder)

        await remote.enqueuePage(ids: [1, 2], total: 4, skip: 0, limit: 2)
        await model.loadMoreProducts()
        await remote.enqueuePage(ids: [3, 4], total: 4, skip: 2, limit: 2)
        await model.loadMoreProducts()
        #expect(model.state.productIDs == [1, 2, 3, 4])

        model.searchText = "phone"
        await remote.enqueuePage(ids: [8], total: 1, skip: 0, limit: 10)
        await model.tryProductSearch()

        await remote.setCategories(["beauty", "laptops"])
        await model.tryCategories()
        #expect(model.state.categorySlugs == ["beauty", "laptops"])

        model.categorySlug = "beauty"
        await remote.enqueuePage(ids: [9], total: 1, skip: 0, limit: 10)
        await model.tryCategoryProducts()

        model.productID = 9
        await model.tryProductDetail()
        await model.runDiagnostic(.delay(milliseconds: 0))
        await model.runDiagnostic(.delay(milliseconds: 5_000))
        for status in [400, 401, 404, 500] {
            await model.runDiagnostic(.status(code: status))
        }

        #expect(await remote.calls == [
            .products(ProductPageRequest(mode: .all, sort: nil, limit: 10, skip: 0)),
            .products(ProductPageRequest(mode: .all, sort: nil, limit: 10, skip: 2)),
            .products(ProductPageRequest(mode: .search("phone"), sort: nil, limit: 10, skip: 0)),
            .categories,
            .products(ProductPageRequest(mode: .category("beauty"), sort: nil, limit: 10, skip: 0)),
            .product(9),
            .diagnostic(.delay(milliseconds: 0)),
            .diagnostic(.delay(milliseconds: 5_000)),
            .diagnostic(.status(code: 400)),
            .diagnostic(.status(code: 401)),
            .diagnostic(.status(code: 404)),
            .diagnostic(.status(code: 500))
        ])
    }

    @Test
    func invalidDiagnosticDelayDoesNotCallOrMutateRetryState() async {
        let remote = RemoteLabServiceSpy()
        let model = RemoteAPILabViewModel(
            remote: remote,
            session: RemoteLabSessionSpy(),
            diagnostics: NetworkDiagnosticRecorder()
        )
        let original = model.state

        await model.runDiagnostic(.delay(milliseconds: 5_001))

        #expect(await remote.calls.isEmpty)
        #expect(model.state == original)
        #expect(model.lastRetryOperation == nil)
    }

    @Test
    func cancelledRemoteTryIsSilent() async {
        let remote = RemoteLabServiceSpy(suspendsProducts: true)
        let model = RemoteAPILabViewModel(
            remote: remote,
            session: RemoteLabSessionSpy(),
            diagnostics: NetworkDiagnosticRecorder()
        )
        let task = Task { await model.tryProductSearch() }
        while await remote.calls.isEmpty { await Task.yield() }

        model.cancelCurrentOperation()
        await task.value

        #expect(model.actualResult == .idle)
        #expect(model.lastRetryOperation == nil)
    }

    @Test(arguments: [
        RemoteServiceError.cancelled,
        RemoteServiceError.status(code: 400, authenticationError: nil),
        RemoteServiceError.status(code: 401, authenticationError: nil),
        RemoteServiceError.status(code: 404, authenticationError: nil),
        RemoteServiceError.status(code: 500, authenticationError: nil)
    ])
    func remoteFailuresAreSilentOnlyForCancellationAndRetainSafeTypedRetry(
        error: RemoteServiceError
    ) async {
        let remote = RemoteLabServiceSpy()
        await remote.failNext(error)
        let model = RemoteAPILabViewModel(
            remote: remote,
            session: RemoteLabSessionSpy(),
            diagnostics: NetworkDiagnosticRecorder()
        )
        model.searchText = "bounded"

        await model.tryProductSearch()

        if error == .cancelled {
            #expect(model.actualResult == .idle)
            #expect(model.lastRetryOperation == nil)
        } else {
            #expect(!model.actualResult.isSuccess)
            #expect(model.lastRetryOperation == .search("bounded"))
            #expect(model.actualResult.message.count < 256)
        }
    }

    @Test
    func remoteRetryUsesLatestDescriptorExactlyOnceAndClearsAfterSuccess() async {
        let remote = RemoteLabServiceSpy()
        let model = RemoteAPILabViewModel(
            remote: remote,
            session: RemoteLabSessionSpy(),
            diagnostics: NetworkDiagnosticRecorder()
        )
        model.productID = 4
        await remote.failNext(.transport)
        await model.tryProductDetail()
        #expect(model.lastRetryOperation == .detail(4))

        await remote.clearCalls()
        await model.retryLastOperation()

        #expect(await remote.calls == [.product(4)])
        #expect(model.lastRetryOperation == nil)
    }

    @Test
    func sessionActionsAreSemanticAndLoginPasswordIsAlwaysClearedAndNeverRetryable() async {
        let outcomes: [SessionLoginResult] = [
            .authenticated(SessionRepositorySnapshot(state: .guest, expiry: nil)),
            .failure(.invalidCredentials),
            .cancelled
        ]
        for outcome in outcomes {
            let session = RemoteLabSessionSpy(loginResult: outcome)
            let remote = RemoteLabServiceSpy()
            let model = RemoteAPILabViewModel(
                remote: remote,
                session: session,
                diagnostics: NetworkDiagnosticRecorder()
            )
            model.username = "learner"
            model.password = "one-shot-secret"

            await model.login()
            #expect(model.password.isEmpty)
            #expect(model.lastRetryOperation == nil)
            #expect(session.loginInputs.count == 1)
            #expect(session.loginInputs.first?.0 == "learner")
            #expect(session.loginInputs.first?.1 == "one-shot-secret")
            #expect(await remote.calls.isEmpty)
        }

        let session = RemoteLabSessionSpy()
        let model = RemoteAPILabViewModel(
            remote: RemoteLabServiceSpy(),
            session: session,
            diagnostics: NetworkDiagnosticRecorder()
        )
        await model.validateSession()
        await model.refreshSession()
        let token = SessionPersistenceRetryToken()
        await model.retrySessionPersistence(token)
        await model.discardSessionPersistenceRetry(token)
        await model.signOut()
        #expect(session.semanticCalls == [.validate, .refresh, .retryPersistence, .discardPersistence, .signOut])
    }

    @Test
    func diagnosticsCopyAndClearOnlyTheBoundedRecorderEvents() async {
        let recorder = NetworkDiagnosticRecorder(capacity: 2)
        await recorder.record(.fixture(operation: "first"))
        await recorder.record(.fixture(operation: "second"))
        await recorder.record(.fixture(operation: "third"))
        let model = RemoteAPILabViewModel(
            remote: RemoteLabServiceSpy(),
            session: RemoteLabSessionSpy(),
            diagnostics: recorder
        )

        await model.refreshDiagnostics()
        #expect(model.state.diagnosticEvents.map(\.operation) == ["second", "third"])
        await model.clearDiagnostics()
        #expect(model.state.diagnosticEvents.isEmpty)
        #expect(await recorder.events().isEmpty)
    }
}

private nonisolated enum DatabaseLabCall: Equatable, Sendable {
    case fetch(String)
    case page(search: String?, afterID: String?, pageSize: Int)
    case create(ExampleRecord)
    case update(ExampleRecord)
    case upsert(ExampleRecord)
    case upsertBatch([ExampleRecord])
    case delete(String)
    case deleteAll

    var isThreeRecordBatch: Bool {
        if case let .upsertBatch(records) = self { records.count == 3 } else { false }
    }
}

private actor DatabaseLabRepositorySpy: ILocalDatabaseExampleRepository {
    private(set) var calls: [DatabaseLabCall] = []
    private var pageResult = LocalDatabasePage<ExampleRecord, String>(
        values: [], nextCursor: nil, hasMore: false
    )
    private var shouldFailNext = false
    private var shouldFailNextPage = false

    var requestedCursors: [String?] {
        calls.compactMap {
            if case let .page(_, afterID, _) = $0 { Optional(afterID) } else { nil }
        }
    }

    func setPage(values: [ExampleRecord], nextCursor: String?, hasMore: Bool) {
        pageResult = LocalDatabasePage(values: values, nextCursor: nextCursor, hasMore: hasMore)
    }

    func failNext() { shouldFailNext = true }
    func failNextPage() { shouldFailNextPage = true }
    func clearCalls() { calls.removeAll() }

    func fetch(id: String) async throws -> ExampleRecord? {
        try record(.fetch(id))
        return nil
    }

    func page(searchText: String?, afterID: String?, pageSize: Int) async throws -> LocalDatabasePage<ExampleRecord, String> {
        try record(.page(search: searchText, afterID: afterID, pageSize: pageSize))
        if shouldFailNextPage {
            shouldFailNextPage = false
            throw DatabaseLabFixtureError.injected
        }
        return pageResult
    }

    func create(id: String, payload: String) async throws {
        try record(.create(ExampleRecord(id: id, payload: payload)))
    }

    func update(id: String, payload: String) async throws {
        try record(.update(ExampleRecord(id: id, payload: payload)))
    }

    func upsert(_ record: ExampleRecord) async throws { try self.record(.upsert(record)) }
    func upsertBatch(_ records: [ExampleRecord]) async throws { try record(.upsertBatch(records)) }
    func delete(id: String) async throws -> Bool { try record(.delete(id)); return true }
    func deleteAll() async throws -> Int { try record(.deleteAll); return 3 }

    private func record(_ call: DatabaseLabCall) throws {
        calls.append(call)
        if shouldFailNext {
            shouldFailNext = false
            throw DatabaseLabFixtureError.injected
        }
    }
}

private nonisolated enum DatabaseLabFixtureError: Error { case injected }

private nonisolated enum RemoteBoundaryCall: Equatable, Sendable {
    case products(ProductPageRequest)
    case categories
    case product(Int)
    case diagnostic(HTTPDiagnosticRequest)
}

private actor RemoteServiceBoundarySpy: IRemoteService {
    private(set) var calls: [RemoteBoundaryCall] = []
    private(set) var authenticationCallCount = 0

    func fetchExample(_ request: ExampleRequest) async throws -> ExampleResponse { throw RemoteServiceError.invalidResponse }
    func products(_ request: ProductPageRequest) async throws -> ProductPageDTO {
        calls.append(.products(request)); return .fixture(ids: [], total: 0, skip: request.skip, limit: request.limit)
    }
    func categories() async throws -> [ProductCategoryDTO] { calls.append(.categories); return [] }
    func product(id: Int) async throws -> ProductDTO { calls.append(.product(id)); return .fixture(id: id) }
    func login(_ request: LoginRequestDTO) async throws -> AuthSessionDTO { authenticationCallCount += 1; throw RemoteServiceError.invalidResponse }
    func me(accessToken: String) async throws -> UserProfileDTO { authenticationCallCount += 1; throw RemoteServiceError.invalidResponse }
    func refresh(_ request: RefreshRequestDTO) async throws -> AuthTokensDTO { authenticationCallCount += 1; throw RemoteServiceError.invalidResponse }
    func diagnostic(_ request: HTTPDiagnosticRequest) async throws -> HTTPDiagnosticDTO {
        calls.append(.diagnostic(request)); return HTTPDiagnosticDTO(statusCode: 200)
    }
}

private actor RemoteLabServiceSpy: IRemoteAPILabService {
    private(set) var calls: [RemoteBoundaryCall] = []
    private var queuedPages: [ProductPageDTO] = []
    private var categoryValues: [String] = []
    private var nextError: RemoteServiceError?
    private let suspendsProducts: Bool

    init(suspendsProducts: Bool = false) { self.suspendsProducts = suspendsProducts }
    func enqueuePage(ids: [Int], total: Int, skip: Int, limit: Int) {
        queuedPages.append(.fixture(ids: ids, total: total, skip: skip, limit: limit))
    }
    func setCategories(_ values: [String]) { categoryValues = values }
    func failNext(_ error: RemoteServiceError) { nextError = error }
    func clearCalls() { calls.removeAll() }

    func products(_ request: ProductPageRequest) async throws -> ProductPageDTO {
        calls.append(.products(request))
        if suspendsProducts { try await Task.sleep(for: .seconds(60)) }
        try throwNextErrorIfNeeded()
        return queuedPages.isEmpty
            ? .fixture(ids: [], total: 0, skip: request.skip, limit: request.limit)
            : queuedPages.removeFirst()
    }
    func categories() async throws -> [ProductCategoryDTO] {
        calls.append(.categories); try throwNextErrorIfNeeded()
        return categoryValues.map { .fixture(slug: $0) }
    }
    func product(id: Int) async throws -> ProductDTO {
        calls.append(.product(id)); try throwNextErrorIfNeeded(); return .fixture(id: id)
    }
    func diagnostic(_ request: HTTPDiagnosticRequest) async throws -> HTTPDiagnosticDTO {
        calls.append(.diagnostic(request)); try throwNextErrorIfNeeded(); return HTTPDiagnosticDTO(statusCode: 200)
    }
    private func throwNextErrorIfNeeded() throws {
        if let nextError { self.nextError = nil; throw nextError }
    }
}

@MainActor
private final class RemoteLabSessionSpy: ISessionActions {
    enum Call: Equatable { case validate, refresh, retryPersistence, discardPersistence, signOut }
    var status = SessionStatusPresentation(session: SessionPresentation(state: .guest, revision: 1), expiry: nil)
    var presentation: SessionPresentation { status.session }
    var loginInputs: [(String, String)] = []
    var semanticCalls: [Call] = []
    var loginResult: SessionLoginResult

    init(loginResult: SessionLoginResult = .cancelled) { self.loginResult = loginResult }
    func bootstrap() async {}
    func retryBootstrap() async {}
    func login(username: String, password: String) async -> SessionLoginResult {
        loginInputs.append((username, password)); return loginResult
    }
    func retryPersistence(_ token: SessionPersistenceRetryToken) async -> SessionPersistenceRetryResult {
        semanticCalls.append(.retryPersistence); return .invalidToken
    }
    func discardPersistenceRetry(_ token: SessionPersistenceRetryToken) async { semanticCalls.append(.discardPersistence) }
    func validateSession() async -> SessionValidationResult { semanticCalls.append(.validate); return .unchanged }
    func refreshSession() async -> SessionValidationResult { semanticCalls.append(.refresh); return .unchanged }
    func signOut() async -> SessionSignOutResult { semanticCalls.append(.signOut); return .guest }
}

private nonisolated extension ProductDTO {
    static func fixture(id: Int) -> ProductDTO {
        ProductDTO(
            id: id, title: "Product \(id)", description: "Description", category: "test",
            price: 1, rating: 5, stock: 1, brand: nil, availabilityStatus: nil,
            reviews: [], images: [], thumbnail: nil
        )
    }
}

private nonisolated extension ProductPageDTO {
    static func fixture(ids: [Int], total: Int, skip: Int, limit: Int) -> ProductPageDTO {
        ProductPageDTO(products: ids.map(ProductDTO.fixture), total: total, skip: skip, limit: limit)
    }
}

private nonisolated extension ProductCategoryDTO {
    static func fixture(slug: String) -> ProductCategoryDTO {
        ProductCategoryDTO(slug: slug, name: slug.capitalized, url: URL(string: "https://example.test/\(slug)")!)
    }
}

private nonisolated extension NetworkDiagnosticEvent {
    static func fixture(operation: String) -> NetworkDiagnosticEvent {
        NetworkDiagnosticEvent(
            operationID: UUID(), operation: operation, method: .get,
            safePath: "/safe", queryKeys: [], statusClass: 2,
            elapsed: .zero, failure: nil, summary: .http(status: 200)
        )
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
