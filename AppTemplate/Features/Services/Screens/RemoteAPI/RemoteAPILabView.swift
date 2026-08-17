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
        ServiceLabGuideView(
            guide: guide,
            result: model.actualResult,
            resetDemoData: { Task { await model.resetDemoData() } }
        ) {
            TextField(AppText.resource("Product search"), text: $model.searchText)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button(AppText.resource("Search")) { Task { await model.tryProductSearch() } }
                    .accessibilityIdentifier(AppAccessibilityIdentifier.action(.tryService))
                Button(AppText.resource("Load Products Page")) { Task { await model.loadMoreProducts() } }
            }
            productIDs
        } advanced: {
            categoryPanel
            detailPanel
            diagnosticPanel
            sessionPanel
            operationControls
            Text(AppText.resource("The lab receives a token-free remote facade. Login, validation, refresh, persistence recovery, and sign out remain semantic session-controller actions."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .navigationTitle(AppText.resource("Remote API"))
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityIdentifier("screen.services.remote-api")
        }
        .onDisappear { model.cancelCurrentOperation() }
    }

    @ViewBuilder
    private var productIDs: some View {
        if model.state.productIDs.isEmpty {
            Text(AppText.resource("No product IDs in the current result."))
                .foregroundStyle(.secondary)
        } else {
            Text(AppText.resource("Product IDs: \(model.state.productIDs.map(String.init).joined(separator: ", "))"))
                .textSelection(.enabled)
        }
    }

    private var categoryPanel: some View {
        VStack(alignment: .leading) {
            Text(AppText.resource("Categories")).font(.headline)
            Button(AppText.resource("Discover Categories")) { Task { await model.tryCategories() } }
            if !model.state.categorySlugs.isEmpty {
                Text(model.state.categorySlugs.joined(separator: ", "))
                    .textSelection(.enabled)
            }
            TextField(AppText.resource("Category slug"), text: $model.categorySlug)
                .textFieldStyle(.roundedBorder)
            Button(AppText.resource("Products in Category")) { Task { await model.tryCategoryProducts() } }
        }
    }

    private var detailPanel: some View {
        VStack(alignment: .leading) {
            Text(AppText.resource("Product Detail")).font(.headline)
            TextField(AppText.resource("Product ID"), value: $model.productID, format: .number)
                .textFieldStyle(.roundedBorder)
            Button(AppText.resource("Load Detail")) { Task { await model.tryProductDetail() } }
        }
    }

    private var diagnosticPanel: some View {
        VStack(alignment: .leading) {
            Text(AppText.resource("HTTP Diagnostics")).font(.headline)
            HStack {
                Button(AppText.resource("Delay 0 ms")) { run(.delay(milliseconds: 0)) }
                Button(AppText.resource("Delay 5000 ms")) { run(.delay(milliseconds: 5_000)) }
            }
            HStack {
                ForEach([400, 401, 404, 500], id: \.self) { status in
                    Button(AppText.resource("Status \(status)")) { run(.status(code: status)) }
                }
            }
            HStack {
                Button(AppText.resource("Refresh Diagnostics")) { Task { await model.refreshDiagnostics() } }
                Button(AppText.resource("Clear Diagnostics")) { Task { await model.clearDiagnostics() } }
            }
            ForEach(model.state.diagnosticEvents, id: \.operationID) { event in
                VStack(alignment: .leading) {
                    Text(event.operation).font(.caption.bold())
                    Text(AppText.resource("\(event.safePath) • status class \(event.statusClass.map(String.init) ?? "none")"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var sessionPanel: some View {
        VStack(alignment: .leading) {
            Text(AppText.resource("Session Actions")).font(.headline)
            TextField(AppText.resource("Username"), text: $model.username)
                .textFieldStyle(.roundedBorder)
            SecureField(AppText.resource("Password"), text: $model.password)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button(AppText.resource("Login")) { Task { await model.login() } }
                Button(AppText.resource("Validate")) { Task { await model.validateSession() } }
                Button(AppText.resource("Refresh")) { Task { await model.refreshSession() } }
                Button(AppText.resource("Sign Out")) { Task { await model.signOut() } }
            }
            if let token = model.pendingPersistenceRetryToken {
                HStack {
                    Button(AppText.resource("Retry Secure Persistence")) {
                        Task { await model.retrySessionPersistence(token) }
                    }
                    Button(AppText.resource("Discard Persistence Retry")) {
                        Task { await model.discardSessionPersistenceRetry(token) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var operationControls: some View {
        if model.state.isLoading {
            Button(AppText.resource("Cancel Current Operation")) { model.cancelCurrentOperation() }
        }
        if model.lastRetryOperation != nil {
            Button(AppText.resource("Retry Last Operation")) { Task { await model.retryLastOperation() } }
        }
    }

    private func run(_ request: HTTPDiagnosticRequest) {
        Task { await model.runDiagnostic(request) }
    }
}
