import Foundation
import Observation

@MainActor
@Observable
final class RemoteAPILabViewModel {
    private static let productPageSize = 10
    private static let maximumSearchCharacters = 128
    private static let maximumCategoryCharacters = 128
    private static let allowedDiagnosticStatuses: Set<Int> = [400, 401, 404, 500]

    private let remote: any IRemoteAPILabService
    private let session: any ISessionActions
    private let diagnostics: NetworkDiagnosticRecorder
    private var currentOperation: Task<Void, Never>?
    private var operationGeneration: UInt64 = 0
    private var canLoadMoreProducts = true

    var username = "emilys"
    var password = ""
    var searchText = "phone"
    var categorySlug = "beauty"
    var productID = 1

    private(set) var state = RemoteAPILabState()
    private(set) var actualResult: ServiceLabResult = .idle
    private(set) var lastRetryOperation: RemoteLabRetryOperation?
    private(set) var pendingPersistenceRetryToken: SessionPersistenceRetryToken?

    var sessionStatus: SessionStatusPresentation { session.status }

    init(
        remote: any IRemoteAPILabService,
        session: any ISessionActions,
        diagnostics: NetworkDiagnosticRecorder
    ) {
        self.remote = remote
        self.session = session
        self.diagnostics = diagnostics
    }

    func tryProductSearch() async {
        guard let search = validatedSearch(searchText) else {
            publishInvalidInput(StoreServicesText.string("Search must contain 1 to 128 characters."))
            return
        }
        await perform(.search(search)) {
            let page = try await self.remote.products(ProductPageRequest(
                mode: .search(search),
                sort: nil,
                limit: Self.productPageSize,
                skip: 0
            ))
            self.apply(page: page, replacing: true)
            return .success(StoreServicesText.string("Search returned \(page.products.count) products."))
        }
    }

    func tryCategories() async {
        await perform(.categories) {
            let categories = try await self.remote.categories()
            self.state.categorySlugs = categories.map(\.slug)
            return .success(StoreServicesText.string("Loaded \(categories.count) categories."))
        }
    }

    func tryCategoryProducts() async {
        guard let slug = validatedCategory(categorySlug) else {
            publishInvalidInput(StoreServicesText.string("Choose a category slug between 1 and 128 characters."))
            return
        }
        await perform(.categoryProducts(slug)) {
            let page = try await self.remote.products(ProductPageRequest(
                mode: .category(slug),
                sort: nil,
                limit: Self.productPageSize,
                skip: 0
            ))
            self.apply(page: page, replacing: true)
            return .success(StoreServicesText.string("Loaded \(page.products.count) products in \(slug)."))
        }
    }

    func tryProductDetail() async {
        guard productID > 0 else {
            publishInvalidInput(StoreServicesText.string("Product ID must be positive."))
            return
        }
        let id = productID
        await perform(.detail(id)) {
            let product = try await self.remote.product(id: id)
            self.state.productIDs = [product.id]
            self.state.nextSkip = 0
            self.canLoadMoreProducts = false
            return .success(StoreServicesText.string("Loaded product \(product.id)."))
        }
    }

    func loadMoreProducts() async {
        guard canLoadMoreProducts, !state.isLoading else { return }
        let skip = state.productIDs.isEmpty ? 0 : state.nextSkip
        await perform(.nextPage) {
            let page = try await self.remote.products(ProductPageRequest(
                mode: .all,
                sort: nil,
                limit: Self.productPageSize,
                skip: skip
            ))
            self.apply(page: page, replacing: skip == 0)
            return .success(StoreServicesText.string("Loaded \(page.products.count) products."))
        }
    }

    func runDiagnostic(_ request: HTTPDiagnosticRequest) async {
        guard isAllowedDiagnostic(request) else {
            publishInvalidInput(StoreServicesText.string("Use delay 0...5000 ms or status 400, 401, 404, or 500."))
            return
        }
        await perform(.diagnostic(request)) {
            let response = try await self.remote.diagnostic(request)
            self.state.diagnosticEvents = Array(await self.diagnostics.events().suffix(100))
            return .success(StoreServicesText.string("Diagnostic completed with status \(response.statusCode)."))
        }
    }

    func login() async {
        guard !username.isEmpty, username.count <= Self.maximumSearchCharacters,
              !password.isEmpty, password.utf8.count <= 4_096
        else {
            password = ""
            publishInvalidInput(StoreServicesText.string("Enter a bounded username and password."))
            return
        }
        let capturedUsername = username
        let capturedPassword = password
        let previousResult = actualResult
        actualResult = .running
        defer { password = "" }

        switch await session.login(username: capturedUsername, password: capturedPassword) {
        case .authenticated:
            pendingPersistenceRetryToken = nil
            lastRetryOperation = nil
            actualResult = .success(StoreServicesText.string("Signed in through the session controller."))
        case let .failure(.persistenceFailed(token)):
            pendingPersistenceRetryToken = token
            lastRetryOperation = nil
            actualResult = .failure(StoreServicesText.string("Sign in completed but secure session data could not be saved."))
        case .failure:
            lastRetryOperation = nil
            actualResult = .failure(StoreServicesText.string("Sign in could not complete."))
        case .cancelled:
            actualResult = previousResult
        }
    }

    func validateSession() async {
        let previousResult = actualResult
        actualResult = .running
        applyValidationResult(
            await session.validateSession(),
            retry: .validate,
            operation: StoreServicesText.string("Session validation"),
            previousResult: previousResult
        )
    }

    func refreshSession() async {
        let previousResult = actualResult
        actualResult = .running
        applyValidationResult(
            await session.refreshSession(),
            retry: .refresh,
            operation: StoreServicesText.string("Session refresh"),
            previousResult: previousResult
        )
    }

    func retrySessionPersistence(_ token: SessionPersistenceRetryToken) async {
        let previousResult = actualResult
        actualResult = .running
        switch await session.retryPersistence(token) {
        case .committed:
            pendingPersistenceRetryToken = nil
            lastRetryOperation = nil
            actualResult = .success(StoreServicesText.string("Secure session persistence completed."))
        case let .failed(nextToken, _):
            pendingPersistenceRetryToken = nextToken
            actualResult = .failure(StoreServicesText.string("Secure session persistence could not complete."))
        case .invalidToken:
            pendingPersistenceRetryToken = nil
            actualResult = .failure(StoreServicesText.string("The persistence retry is no longer available."))
        case .cancelled:
            actualResult = previousResult
        }
    }

    func discardSessionPersistenceRetry(_ token: SessionPersistenceRetryToken) async {
        await session.discardPersistenceRetry(token)
        pendingPersistenceRetryToken = nil
        actualResult = .success(StoreServicesText.string("Discarded the pending persistence retry."))
    }

    func signOut() async {
        let previousResult = actualResult
        actualResult = .running
        switch await session.signOut() {
        case .guest:
            pendingPersistenceRetryToken = nil
            lastRetryOperation = nil
            actualResult = .success(StoreServicesText.string("Signed out."))
        case .deletionFailed:
            actualResult = .failure(StoreServicesText.string("Sign out could not clear secure session data."))
        case .cancelled:
            actualResult = previousResult
        }
    }

    func refreshDiagnostics() async {
        state.diagnosticEvents = Array(await diagnostics.events().suffix(100))
    }

    func clearDiagnostics() async {
        await diagnostics.clear()
        state.diagnosticEvents = []
        actualResult = .success(StoreServicesText.string("Cleared network diagnostics."))
    }

    func cancelCurrentOperation() {
        currentOperation?.cancel()
    }

    func retryLastOperation() async {
        guard let operation = lastRetryOperation else { return }
        switch operation {
        case let .search(value):
            searchText = value
            await tryProductSearch()
        case .categories:
            await tryCategories()
        case let .categoryProducts(slug):
            categorySlug = slug
            await tryCategoryProducts()
        case let .detail(id):
            productID = id
            await tryProductDetail()
        case .nextPage:
            await loadMoreProducts()
        case let .diagnostic(request):
            await runDiagnostic(request)
        case .validate:
            await validateSession()
        case .refresh:
            await refreshSession()
        }
    }

    private func perform(
        _ descriptor: RemoteLabRetryOperation,
        operation: @escaping @MainActor () async throws -> ServiceLabResult
    ) async {
        currentOperation?.cancel()
        operationGeneration &+= 1
        let generation = operationGeneration
        let previousResult = actualResult
        let previousState = state
        state.isLoading = true
        actualResult = .running

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let result = try await operation()
                guard generation == self.operationGeneration else { return }
                self.lastRetryOperation = nil
                self.actualResult = result
            } catch is CancellationError {
                guard generation == self.operationGeneration else { return }
                self.state = previousState
                self.actualResult = previousResult
            } catch let error as RemoteServiceError where error == .cancelled {
                guard generation == self.operationGeneration else { return }
                self.state = previousState
                self.actualResult = previousResult
            } catch {
                guard generation == self.operationGeneration else { return }
                self.lastRetryOperation = descriptor
                self.actualResult = .failure(Self.safeMessage(for: error))
            }
            if generation == self.operationGeneration {
                self.state.isLoading = false
            }
        }
        currentOperation = task
        await task.value
        if generation == operationGeneration { currentOperation = nil }
    }

    private func apply(page: ProductPageDTO, replacing: Bool) {
        let ids = page.products.map(\.id)
        state.productIDs = replacing ? ids : state.productIDs + ids
        state.nextSkip = page.skip + page.products.count
        canLoadMoreProducts = state.nextSkip < page.total && !page.products.isEmpty
    }

    private func applyValidationResult(
        _ result: SessionValidationResult,
        retry: RemoteLabRetryOperation,
        operation: String,
        previousResult: ServiceLabResult
    ) {
        switch result {
        case .committed:
            pendingPersistenceRetryToken = nil
            lastRetryOperation = nil
            actualResult = .success(StoreServicesText.string("\(operation) updated the session."))
        case let .persistenceFailed(token, _):
            pendingPersistenceRetryToken = token
            lastRetryOperation = nil
            actualResult = .failure(StoreServicesText.string("\(operation) completed but secure session data could not be saved."))
        case .unchanged:
            lastRetryOperation = nil
            actualResult = .success(StoreServicesText.string("\(operation) completed with no status change."))
        case .failed:
            lastRetryOperation = retry
            actualResult = .failure(StoreServicesText.string("\(operation) could not complete."))
        case .cancelled:
            actualResult = previousResult
        }
    }

    private func validatedSearch(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= Self.maximumSearchCharacters else { return nil }
        return trimmed
    }

    private func validatedCategory(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= Self.maximumCategoryCharacters else { return nil }
        return trimmed
    }

    private func isAllowedDiagnostic(_ request: HTTPDiagnosticRequest) -> Bool {
        switch request {
        case let .delay(milliseconds):
            (0...5_000).contains(milliseconds)
        case let .status(code):
            Self.allowedDiagnosticStatuses.contains(code)
        }
    }

    private func publishInvalidInput(_ message: String) {
        actualResult = .failure(message)
    }

    private static func safeMessage(for error: any Error) -> String {
        guard let remoteError = error as? RemoteServiceError else {
            return StoreServicesText.string("The remote operation could not complete.")
        }
        return switch remoteError {
        case .cancelled:
            ""
        case .transport:
            StoreServicesText.string("The remote service is unavailable.")
        case let .status(code, _):
            StoreServicesText.string("The remote service returned HTTP status \(code).")
        case .invalidResponse:
            StoreServicesText.string("The remote service returned an invalid response.")
        }
    }
}
