import Foundation
import Observation

@MainActor
@Observable
final class LocalDatabaseLabViewModel {
    private static let maximumIDCharacters = 128
    private static let maximumPayloadBytes = 4_096
    private static let maximumSearchCharacters = 128
    private static let maximumBatchCount = 50

    private let repository: any ILocalDatabaseExampleRepository
    private var currentOperation: Task<Void, Never>?
    private var operationGeneration: UInt64 = 0

    private(set) var state: LocalDatabaseLabState
    private(set) var actualResult: ServiceLabResult = .idle
    private(set) var lastRetryOperation: LocalDatabaseLabRetryOperation?

    var draftID = "demo-alpha"
    var draftPayload = "Alpha payload"
    var batchDrafts: [ExampleRecord]

    var searchText: String {
        get { state.searchText }
        set { state.searchText = String(newValue.prefix(Self.maximumSearchCharacters + 1)) }
    }

    init(
        repository: any ILocalDatabaseExampleRepository,
        pageSize: Int = 20
    ) {
        self.repository = repository
        batchDrafts = Self.demoRecords
        state = LocalDatabaseLabState(
            pageSize: (1...50).contains(pageSize) ? pageSize : 20
        )
    }

    func fetchByID() async {
        guard let id = validatedID(draftID) else {
            publishInvalidInput(AppText.string("Enter an ID between 1 and 128 characters."))
            return
        }
        await perform(.fetch(id)) { [repository] in
            let record = try await repository.fetch(id: id)
            self.state.records = record.map { [$0] } ?? []
            self.state.nextCursor = nil
            self.state.hasMore = false
            return .success(record == nil
                ? AppText.string("No matching record.")
                : AppText.string("Fetched \(id)."))
        }
    }

    func createDraft() async {
        guard let record = validatedDraft() else {
            publishInvalidInput(AppText.string("Enter a bounded ID and payload before creating."))
            return
        }
        await perform(.create(record)) { [repository] in
            try await repository.create(id: record.id, payload: record.payload)
            try await self.reloadAfterMutation()
            return .success(AppText.string("Created \(record.id) and reloaded the first page."))
        }
    }

    func updateDraft() async {
        guard let record = validatedDraft() else {
            publishInvalidInput(AppText.string("Enter a bounded ID and payload before updating."))
            return
        }
        await perform(.update(record)) { [repository] in
            try await repository.update(id: record.id, payload: record.payload)
            try await self.reloadAfterMutation()
            return .success(AppText.string("Updated \(record.id) and reloaded the first page."))
        }
    }

    func upsertDraft() async {
        guard let record = validatedDraft() else {
            publishInvalidInput(AppText.string("Enter a bounded ID and payload before upserting."))
            return
        }
        await perform(.upsert(record)) { [repository] in
            try await repository.upsert(record)
            try await self.reloadAfterMutation()
            return .success(AppText.string("Upserted \(record.id) and reloaded the first page."))
        }
    }

    func upsertBatch() async {
        guard let records = validatedBatch(batchDrafts) else {
            publishInvalidInput(AppText.string("The batch must contain 1 to 50 bounded records with unique IDs."))
            return
        }
        await perform(.upsertBatch(records)) { [repository] in
            try await repository.upsertBatch(records)
            try await self.reloadAfterMutation()
            return .success(AppText.string("Upserted \(records.count) records and reloaded the first page."))
        }
    }

    func setPageSize(_ value: Int) async {
        guard (1...50).contains(value) else { return }
        currentOperation?.cancel()
        state.pageSize = value
        state.records = []
        state.nextCursor = nil
        state.hasMore = false
        await loadPage(afterID: nil, replacing: true)
    }

    func refresh() async {
        guard validatedSearch(state.searchText) != nil else {
            publishInvalidInput(AppText.string("Search text must be at most 128 characters."))
            return
        }
        await loadPage(afterID: nil, replacing: true)
    }

    func loadMore() async {
        guard state.hasMore, !state.isLoading else { return }
        await loadPage(afterID: state.nextCursor, replacing: false)
    }

    func deleteByID() async {
        guard let id = validatedID(draftID) else {
            publishInvalidInput(AppText.string("Enter an ID between 1 and 128 characters."))
            return
        }
        await perform(.delete(id)) { [repository] in
            let deleted = try await repository.delete(id: id)
            try await self.reloadAfterMutation()
            return .success(deleted
                ? AppText.string("Deleted \(id).")
                : AppText.string("No matching record to delete."))
        }
    }

    func deleteAllConfirmed() async {
        await perform(.deleteAll) { [repository] in
            let count = try await repository.deleteAll()
            try await self.reloadAfterMutation()
            return .success(AppText.string("Deleted \(count) demo records."))
        }
    }

    func resetDemoData() async {
        await perform(.reset) { [repository] in
            _ = try await repository.deleteAll()
            try await repository.upsertBatch(Self.demoRecords)
            try await self.reloadAfterMutation()
            return .success(AppText.string("Reset the three local database demo records."))
        }
    }

    func retryLastOperation() async {
        guard let operation = lastRetryOperation else { return }
        switch operation {
        case let .fetch(id):
            draftID = id
            await fetchByID()
        case let .page(search, afterID, pageSize):
            state.searchText = search ?? ""
            state.pageSize = pageSize
            await loadPage(afterID: afterID, replacing: afterID == nil)
        case let .create(record):
            await retryMutation(operation) { [repository] in
                try await repository.create(id: record.id, payload: record.payload)
                return AppText.string("Created \(record.id).")
            }
        case let .update(record):
            await retryMutation(operation) { [repository] in
                try await repository.update(id: record.id, payload: record.payload)
                return AppText.string("Updated \(record.id).")
            }
        case let .upsert(record):
            await retryMutation(operation) { [repository] in
                try await repository.upsert(record)
                return AppText.string("Upserted \(record.id).")
            }
        case let .upsertBatch(records):
            await retryMutation(operation) { [repository] in
                try await repository.upsertBatch(records)
                return AppText.string("Upserted \(records.count) records.")
            }
        case let .delete(id):
            await retryMutation(operation) { [repository] in
                _ = try await repository.delete(id: id)
                return AppText.string("Retried delete for \(id).")
            }
        case .deleteAll:
            await retryMutation(operation) { [repository] in
                let count = try await repository.deleteAll()
                return AppText.string("Deleted \(count) demo records.")
            }
        case .reset:
            await resetDemoData()
        }
    }

    func cancelCurrentOperation() {
        currentOperation?.cancel()
    }

    private func loadPage(afterID: String?, replacing: Bool) async {
        let search = normalizedSearch(state.searchText)
        let pageSize = state.pageSize
        await perform(.page(search: search, afterID: afterID, pageSize: pageSize)) {
            let page = try await self.repository.page(
                searchText: search,
                afterID: afterID,
                pageSize: pageSize
            )
            self.state.records = replacing
                ? page.values
                : self.state.records + page.values
            self.state.nextCursor = page.nextCursor
            self.state.hasMore = page.hasMore
            return .success(AppText.string("Loaded \(page.values.count) records."))
        }
    }

    private func reloadAfterMutation() async throws {
        state.records = []
        state.nextCursor = nil
        state.hasMore = false
        let search = normalizedSearch(state.searchText)
        let pageSize = state.pageSize
        let page: LocalDatabasePage<ExampleRecord, String>
        do {
            page = try await repository.page(
                searchText: search,
                afterID: nil,
                pageSize: pageSize
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw LocalDatabaseLabControlError.reload(
                search: search,
                pageSize: pageSize
            )
        }
        state.records = page.values
        state.nextCursor = page.nextCursor
        state.hasMore = page.hasMore
    }

    private func retryMutation(
        _ descriptor: LocalDatabaseLabRetryOperation,
        operation: @escaping @MainActor () async throws -> String
    ) async {
        await perform(descriptor) {
            let message = try await operation()
            try await self.reloadAfterMutation()
            return .success(message)
        }
    }

    private func perform(
        _ descriptor: LocalDatabaseLabRetryOperation,
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
            } catch let error as LocalDatabaseLabControlError {
                guard generation == self.operationGeneration else { return }
                self.state = previousState
                switch error {
                case let .reload(search, pageSize):
                    self.lastRetryOperation = .page(
                        search: search,
                        afterID: nil,
                        pageSize: pageSize
                    )
                }
                self.actualResult = .failure(AppText.string("The mutation completed, but the first page could not reload."))
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

    private func validatedDraft() -> ExampleRecord? {
        guard let id = validatedID(draftID),
              draftPayload.utf8.count <= Self.maximumPayloadBytes
        else { return nil }
        return ExampleRecord(id: id, payload: draftPayload)
    }

    private func validatedBatch(_ records: [ExampleRecord]) -> [ExampleRecord]? {
        guard (1...Self.maximumBatchCount).contains(records.count),
              Set(records.map(\.id)).count == records.count,
              records.allSatisfy({ validatedID($0.id) != nil && $0.payload.utf8.count <= Self.maximumPayloadBytes })
        else { return nil }
        return records
    }

    private func validatedID(_ value: String) -> String? {
        guard value.contains(where: { !$0.isWhitespace }),
              value.count <= Self.maximumIDCharacters
        else { return nil }
        return value
    }

    private func validatedSearch(_ value: String) -> String? {
        value.count <= Self.maximumSearchCharacters ? value : nil
    }

    private func normalizedSearch(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func publishInvalidInput(_ message: String) {
        actualResult = .failure(message)
    }

    private static func safeMessage(for error: any Error) -> String {
        switch error {
        case ExampleRecordRepositoryError.alreadyExists:
            AppText.string("Create requires an ID that does not already exist.")
        case ExampleRecordRepositoryError.notFound:
            AppText.string("Update requires an existing ID.")
        case ExampleRecordRepositoryError.invalidID,
             ExampleRecordRepositoryError.invalidPageSize:
            AppText.string("The local database input was invalid.")
        default:
            AppText.string("The local database operation could not complete.")
        }
    }

    private static let demoRecords = [
        ExampleRecord(id: "demo-alpha", payload: "Alpha payload"),
        ExampleRecord(id: "demo-beta", payload: "Beta payload"),
        ExampleRecord(id: "demo-gamma", payload: "Gamma payload")
    ]
}

private nonisolated enum LocalDatabaseLabControlError: Error {
    case reload(search: String?, pageSize: Int)
}
