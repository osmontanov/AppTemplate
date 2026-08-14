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
                Button("Fetch") { Task { await model.fetchByID() } }
                Button("Create") { Task { await model.createDraft() } }
                Button("Refresh") { Task { await model.refresh() } }
            }
            recordsPresentation
        } advanced: {
            searchAndPaging
            HStack {
                Button("Update") { Task { await model.updateDraft() } }
                Button("Upsert") { Task { await model.upsertDraft() } }
                Button("Batch Upsert") { Task { await model.upsertBatch() } }
            }
            HStack {
                Button("Delete ID") { Task { await model.deleteByID() } }
                Button("Delete All", role: .destructive) {
                    isDeleteAllConfirmationPresented = true
                }
            }
            operationControls
            Text("Create rejects an existing ID, Update requires one, and Upsert demonstrates both insert and replacement through the typed repository.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Local Database")
        .accessibilityIdentifier("screen.services.local-database")
        .alert("Delete all demo records?", isPresented: $isDeleteAllConfirmationPresented) {
            Button("Delete All", role: .destructive) {
                Task { await model.deleteAllConfirmed() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Only ExampleRecord values owned by this learning lab are deleted.")
        }
        .onDisappear { model.cancelCurrentOperation() }
    }

    private var draftEditor: some View {
        VStack(alignment: .leading) {
            TextField("Record ID", text: $model.draftID)
                .textFieldStyle(.roundedBorder)
            TextField("Payload", text: $model.draftPayload)
                .textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder
    private var recordsPresentation: some View {
        if model.state.records.isEmpty {
            Text("No records in the current result.")
                .foregroundStyle(.secondary)
        } else {
            ForEach(model.state.records) { record in
                LabeledContent(record.id, value: String(record.payload.prefix(120)))
            }
        }
    }

    private var searchAndPaging: some View {
        VStack(alignment: .leading) {
            TextField("Search IDs and payloads", text: $model.searchText)
                .textFieldStyle(.roundedBorder)
            Stepper(
                "Page size: \(model.state.pageSize)",
                value: Binding(
                    get: { model.state.pageSize },
                    set: { value in Task { await model.setPageSize(value) } }
                ),
                in: 1...50
            )
            HStack {
                Button("Search / First Page") { Task { await model.refresh() } }
                Button("Load More") { Task { await model.loadMore() } }
                    .disabled(!model.state.hasMore)
            }
            LabeledContent("Next cursor", value: model.state.nextCursor ?? "End")
        }
    }

    @ViewBuilder
    private var operationControls: some View {
        if model.lastRetryOperation != nil {
            Button("Retry Last Operation") {
                Task { await model.retryLastOperation() }
            }
        }
        if model.state.isLoading {
            Button("Cancel Current Operation") { model.cancelCurrentOperation() }
        }
    }
}
