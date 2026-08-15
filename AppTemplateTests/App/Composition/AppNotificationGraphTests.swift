import Foundation
import Testing
@testable import AppTemplate

@MainActor
struct AppNotificationGraphTests {
    @Test
    func liveReminderAttachmentDirectoryCanonicalizesTheTrustedTemporaryRoot() throws {
        let fileManager = FileManager.default
        let fixtureRoot = fileManager.temporaryDirectory
            .resolvingSymlinksInPath()
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let physicalRoot = fixtureRoot.appendingPathComponent("physical", isDirectory: true)
        let lexicalRoot = fixtureRoot.appendingPathComponent("lexical", isDirectory: true)
        try fileManager.createDirectory(
            at: physicalRoot,
            withIntermediateDirectories: true
        )
        try fileManager.createSymbolicLink(
            at: lexicalRoot,
            withDestinationURL: physicalRoot
        )
        defer { try? fileManager.removeItem(at: fixtureRoot) }

        let directory = AppNotificationGraph.liveReminderAttachmentDirectory(
            temporaryDirectory: lexicalRoot
        )

        #expect(directory == physicalRoot.appendingPathComponent(
            "AppTemplate-ProductReminderAttachments",
            isDirectory: true
        ))
    }

    @Test
    func graphExposesOneServiceCatalogHistoryAndReminderIdentity() async throws {
        let graph = AppNotificationGraph.inMemory(
            settings: .productReminderFixture(status: .authorized),
            imageLoader: FailClosedImageLoader(),
            clock: ProductReminderFixtures.clock
        )
        let app = AppDependencies.preview(
            appInfo: AppInfoService(displayName: "Graph", version: "1"),
            remoteService: FailClosedRemoteService(),
            diagnostics: NetworkDiagnosticRecorder(),
            imageLoader: FailClosedImageLoader(),
            notificationGraph: graph
        )
        let session = GraphSessionActions()
        let store = app.makeStoreDependencies(session: session)

        #expect(app.localNotifications.service as AnyObject === graph.dependencies.service as AnyObject)
        #expect(app.localNotifications.categoryCatalog as AnyObject === graph.dependencies.categoryCatalog as AnyObject)
        #expect(app.localNotifications.eventHistory === graph.dependencies.eventHistory)
        #expect(store.reminders as AnyObject === graph.reminders as AnyObject)

        _ = try await store.reminders.schedule(
            product: .fixture(id: 7, title: "Graph Product"),
            selection: .quickTest
        )
        #expect(await graph.dependencies.service.pending().map(\.id.value) == [
            "store.product-reminder.7"
        ])
        #expect(await graph.dependencies.categoryCatalog.categories() == [
            StoreProductNotificationCategory.make()
        ])
    }

    @Test(.timeLimit(.minutes(1)))
    func queueOverflowArrivesInTheSoleSafeHistory() async {
        let graph = AppNotificationGraph.inMemory(clock: ProductReminderFixtures.clock)
        for id in 1...34 {
            await graph.dependencies.navigationCoordinator.deliver(
                .navigate(.openProduct(id))
            )
        }

        let records = await graph.dependencies.eventHistory.records()
        #expect(records.count == 2)
        #expect(records.allSatisfy {
            $0.summary == LocalNotificationEventSummary(
                kind: .diagnostic,
                status: .rejected,
                diagnosticReason: .notificationQueueOverflow
            )
        })
    }
}

@MainActor
private final class GraphSessionActions: ISessionActions {
    var status: SessionStatusPresentation { .init(session: presentation, expiry: nil) }
    var presentation = SessionPresentation(state: .guest, revision: 0)
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
        return .cancelled
    }
    func discardPersistenceRetry(_ token: SessionPersistenceRetryToken) async {
        _ = token
    }
    func validateSession() async -> SessionValidationResult { .unchanged }
    func refreshSession() async -> SessionValidationResult { .unchanged }
    func signOut() async -> SessionSignOutResult { .cancelled }
}
