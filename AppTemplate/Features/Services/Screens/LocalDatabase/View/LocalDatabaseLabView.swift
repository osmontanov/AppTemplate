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
                Button(AppText.resource("Fetch")) { Task { await model.fetchByID() } }
                Button(AppText.resource("Create")) { Task { await model.createDraft() } }
                Button(AppText.resource("Refresh")) { Task { await model.refresh() } }
            }
            recordsPresentation
        } advanced: {
            searchAndPaging
            HStack {
                Button(AppText.resource("Update")) { Task { await model.updateDraft() } }
                Button(AppText.resource("Upsert")) { Task { await model.upsertDraft() } }
                Button(AppText.resource("Batch Upsert")) { Task { await model.upsertBatch() } }
            }
            HStack {
                Button(AppText.resource("Delete ID")) { Task { await model.deleteByID() } }
                Button(AppText.resource("Delete All"), role: .destructive) {
                    isDeleteAllConfirmationPresented = true
                }
            }
            operationControls
            Text(AppText.resource("Create rejects an existing ID, Update requires one, and Upsert demonstrates both insert and replacement through the typed repository."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .navigationTitle(AppText.resource("Local Database"))
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityIdentifier("screen.services.local-database")
        }
        .alert(AppText.resource("Delete all demo records?"), isPresented: $isDeleteAllConfirmationPresented) {
            Button(AppText.resource("Delete All"), role: .destructive) {
                Task { await model.deleteAllConfirmed() }
            }
            Button(AppText.resource("Cancel"), role: .cancel) {}
        } message: {
            Text(AppText.resource("Only ExampleRecord values owned by this learning lab are deleted."))
        }
        .onDisappear { model.cancelCurrentOperation() }
    }

    private var draftEditor: some View {
        VStack(alignment: .leading) {
            TextField(AppText.resource("Record ID"), text: $model.draftID)
                .textFieldStyle(.roundedBorder)
            TextField(AppText.resource("Payload"), text: $model.draftPayload)
                .textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder
    private var recordsPresentation: some View {
        if model.state.records.isEmpty {
            Text(AppText.resource("No records in the current result."))
                .foregroundStyle(.secondary)
        } else {
            ForEach(model.state.records) { record in
                LabeledContent(record.id, value: String(record.payload.prefix(120)))
            }
        }
    }

    private var searchAndPaging: some View {
        VStack(alignment: .leading) {
            TextField(AppText.resource("Search IDs and payloads"), text: $model.searchText)
                .textFieldStyle(.roundedBorder)
            Stepper(
                AppText.resource("Page size: \(model.state.pageSize)"),
                value: Binding(
                    get: { model.state.pageSize },
                    set: { value in Task { await model.setPageSize(value) } }
                ),
                in: 1...50
            )
            HStack {
                Button(AppText.resource("Search / First Page")) { Task { await model.refresh() } }
                    .accessibilityIdentifier(AppAccessibilityIdentifier.action(.tryService))
                Button(AppText.resource("Load More")) { Task { await model.loadMore() } }
                    .disabled(!model.state.hasMore)
                    .accessibilityIdentifier("action.services.local-database.load-more")
            }
            LabeledContent(
                AppText.resource("Next cursor"),
                value: model.state.nextCursor ?? AppText.string("End")
            )
        }
    }

    @ViewBuilder
    private var operationControls: some View {
        if model.lastRetryOperation != nil {
            Button(AppText.resource("Retry Last Operation")) {
                Task { await model.retryLastOperation() }
            }
        }
        if model.state.isLoading {
            Button(AppText.resource("Cancel Current Operation")) { model.cancelCurrentOperation() }
        }
    }
}
