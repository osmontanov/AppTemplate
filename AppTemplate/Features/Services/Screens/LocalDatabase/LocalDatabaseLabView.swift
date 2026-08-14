import SwiftUI

struct LocalDatabaseLabView: View {
    private let guide: ServiceLabGuide
    @State private var model: LocalDatabaseLabViewModel
    @State private var isDeleteAllConfirmationPresented = false

    init(
        guide: ServiceLabGuide,
        repository: any ILocalDatabaseExampleRepository
    ) {
        self.guide = guide
        _model = State(initialValue: LocalDatabaseLabViewModel(
            repository: repository
        ))
    }

    var body: some View {
        ServiceLabGuideView(
            guide: guide,
            result: model.actualResult,
            resetDemoData: { Task { await model.resetDemoData() } }
        ) {
            draftEditor
            HStack {
                Button(StoreServicesText.resource("Fetch")) { Task { await model.fetchByID() } }
                Button(StoreServicesText.resource("Create")) { Task { await model.createDraft() } }
                Button(StoreServicesText.resource("Refresh")) { Task { await model.refresh() } }
            }
            recordsPresentation
        } advanced: {
            searchAndPaging
            HStack {
                Button(StoreServicesText.resource("Update")) { Task { await model.updateDraft() } }
                Button(StoreServicesText.resource("Upsert")) { Task { await model.upsertDraft() } }
                Button(StoreServicesText.resource("Batch Upsert")) { Task { await model.upsertBatch() } }
            }
            HStack {
                Button(StoreServicesText.resource("Delete ID")) { Task { await model.deleteByID() } }
                Button(StoreServicesText.resource("Delete All"), role: .destructive) {
                    isDeleteAllConfirmationPresented = true
                }
            }
            operationControls
            Text(StoreServicesText.resource("Create rejects an existing ID, Update requires one, and Upsert demonstrates both insert and replacement through the typed repository."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .navigationTitle(StoreServicesText.resource("Local Database"))
        .accessibilityIdentifier("screen.services.local-database")
        .alert(StoreServicesText.resource("Delete all demo records?"), isPresented: $isDeleteAllConfirmationPresented) {
            Button(StoreServicesText.resource("Delete All"), role: .destructive) {
                Task { await model.deleteAllConfirmed() }
            }
            Button(StoreServicesText.resource("Cancel"), role: .cancel) {}
        } message: {
            Text(StoreServicesText.resource("Only ExampleRecord values owned by this learning lab are deleted."))
        }
        .onDisappear { model.cancelCurrentOperation() }
    }

    private var draftEditor: some View {
        VStack(alignment: .leading) {
            TextField(StoreServicesText.resource("Record ID"), text: $model.draftID)
                .textFieldStyle(.roundedBorder)
            TextField(StoreServicesText.resource("Payload"), text: $model.draftPayload)
                .textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder
    private var recordsPresentation: some View {
        if model.state.records.isEmpty {
            Text(StoreServicesText.resource("No records in the current result."))
                .foregroundStyle(.secondary)
        } else {
            ForEach(model.state.records) { record in
                LabeledContent(record.id, value: String(record.payload.prefix(120)))
            }
        }
    }

    private var searchAndPaging: some View {
        VStack(alignment: .leading) {
            TextField(StoreServicesText.resource("Search IDs and payloads"), text: $model.searchText)
                .textFieldStyle(.roundedBorder)
            Stepper(
                StoreServicesText.resource("Page size: \(model.state.pageSize)"),
                value: Binding(
                    get: { model.state.pageSize },
                    set: { value in Task { await model.setPageSize(value) } }
                ),
                in: 1...50
            )
            HStack {
                Button(StoreServicesText.resource("Search / First Page")) { Task { await model.refresh() } }
                Button(StoreServicesText.resource("Load More")) { Task { await model.loadMore() } }
                    .disabled(!model.state.hasMore)
            }
            LabeledContent(
                StoreServicesText.resource("Next cursor"),
                value: model.state.nextCursor ?? StoreServicesText.string("End")
            )
        }
    }

    @ViewBuilder
    private var operationControls: some View {
        if model.lastRetryOperation != nil {
            Button(StoreServicesText.resource("Retry Last Operation")) {
                Task { await model.retryLastOperation() }
            }
        }
        if model.state.isLoading {
            Button(StoreServicesText.resource("Cancel Current Operation")) { model.cancelCurrentOperation() }
        }
    }
}
