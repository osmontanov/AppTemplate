import SwiftUI

struct RemoteAPILabView: View {
    private let guide: ServiceLabGuide
    @State private var model: RemoteAPILabViewModel

    init(
        guide: ServiceLabGuide,
        remote: any IRemoteAPILabService,
        session: any ISessionActions,
        diagnostics: NetworkDiagnosticRecorder
    ) {
        self.guide = guide
        _model = State(initialValue: RemoteAPILabViewModel(
            remote: remote,
            session: session,
            diagnostics: diagnostics
        ))
    }

    var body: some View {
        ServiceLabGuideView(guide: guide, result: model.actualResult) {
            TextField("Product search", text: $model.searchText)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Search") { Task { await model.tryProductSearch() } }
                Button("Load Products Page") { Task { await model.loadMoreProducts() } }
            }
            productIDs
        } advanced: {
            categoryPanel
            detailPanel
            diagnosticPanel
            sessionPanel
            operationControls
            Text("The lab receives a token-free remote facade. Login, validation, refresh, persistence recovery, and sign out remain semantic session-controller actions.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Remote API")
        .accessibilityIdentifier("screen.services.remote-api")
        .onDisappear { model.cancelCurrentOperation() }
    }

    @ViewBuilder
    private var productIDs: some View {
        if model.state.productIDs.isEmpty {
            Text("No product IDs in the current result.")
                .foregroundStyle(.secondary)
        } else {
            Text("Product IDs: \(model.state.productIDs.map(String.init).joined(separator: ", "))")
                .textSelection(.enabled)
        }
    }

    private var categoryPanel: some View {
        VStack(alignment: .leading) {
            Text("Categories").font(.headline)
            Button("Discover Categories") { Task { await model.tryCategories() } }
            if !model.state.categorySlugs.isEmpty {
                Text(model.state.categorySlugs.joined(separator: ", "))
                    .textSelection(.enabled)
            }
            TextField("Category slug", text: $model.categorySlug)
                .textFieldStyle(.roundedBorder)
            Button("Products in Category") { Task { await model.tryCategoryProducts() } }
        }
    }

    private var detailPanel: some View {
        VStack(alignment: .leading) {
            Text("Product Detail").font(.headline)
            TextField("Product ID", value: $model.productID, format: .number)
                .textFieldStyle(.roundedBorder)
            Button("Load Detail") { Task { await model.tryProductDetail() } }
        }
    }

    private var diagnosticPanel: some View {
        VStack(alignment: .leading) {
            Text("HTTP Diagnostics").font(.headline)
            HStack {
                Button("Delay 0 ms") { run(.delay(milliseconds: 0)) }
                Button("Delay 5000 ms") { run(.delay(milliseconds: 5_000)) }
            }
            HStack {
                ForEach([400, 401, 404, 500], id: \.self) { status in
                    Button("Status \(status)") { run(.status(code: status)) }
                }
            }
            HStack {
                Button("Refresh Diagnostics") { Task { await model.refreshDiagnostics() } }
                Button("Clear Diagnostics") { Task { await model.clearDiagnostics() } }
            }
            ForEach(model.state.diagnosticEvents, id: \.operationID) { event in
                VStack(alignment: .leading) {
                    Text(event.operation).font(.caption.bold())
                    Text("\(event.safePath) • status class \(event.statusClass.map(String.init) ?? "none")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var sessionPanel: some View {
        VStack(alignment: .leading) {
            Text("Session Actions").font(.headline)
            TextField("Username", text: $model.username)
                .textFieldStyle(.roundedBorder)
            SecureField("Password", text: $model.password)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Login") { Task { await model.login() } }
                Button("Validate") { Task { await model.validateSession() } }
                Button("Refresh") { Task { await model.refreshSession() } }
                Button("Sign Out") { Task { await model.signOut() } }
            }
            if let token = model.pendingPersistenceRetryToken {
                HStack {
                    Button("Retry Secure Persistence") {
                        Task { await model.retrySessionPersistence(token) }
                    }
                    Button("Discard Persistence Retry") {
                        Task { await model.discardSessionPersistenceRetry(token) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var operationControls: some View {
        if model.state.isLoading {
            Button("Cancel Current Operation") { model.cancelCurrentOperation() }
        }
        if model.lastRetryOperation != nil {
            Button("Retry Last Operation") { Task { await model.retryLastOperation() } }
        }
    }

    private func run(_ request: HTTPDiagnosticRequest) {
        Task { await model.runDiagnostic(request) }
    }
}
