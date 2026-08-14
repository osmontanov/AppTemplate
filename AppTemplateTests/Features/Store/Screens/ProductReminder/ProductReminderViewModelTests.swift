import Foundation
import Testing
@testable import AppTemplate

@MainActor
struct ProductReminderViewModelTests {
    @Test
    func calendarPresentationResolvesTheSelectedTimeZoneAndLocale() {
        let model = ProductReminderModel(
            selection: .calendar(
                date: Date(timeIntervalSince1970: 1_800_000_000),
                timeZone: TimeZone(identifier: "Asia/Tokyo")!
            ),
            intervalText: "60",
            calendarDate: Date(timeIntervalSince1970: 1_800_000_000),
            calendarTimeZone: TimeZone(identifier: "Asia/Tokyo")!
        )

        #expect(model.calendarPresentation(locale: Locale(identifier: "fr_FR")) == .init(
            date: "15 janvier 2027",
            time: "17:00",
            timeZone: "heure normale du Japon"
        ))
    }

    @Test(arguments: [
        ("0", false),
        ("604801", false),
        ("nan", false),
        ("59", true),
        ("not-a-number", false)
    ])
    func invalidIntervalsSelectTheIntervalField(
        _ text: String,
        _ repeats: Bool
    ) {
        let model = intervalModel(text: text, repeats: repeats)
        #expect(model.firstInvalidField(now: ProductReminderViewModelFixtures.now) == .interval)
    }

    @Test(arguments: [
        ("1", false),
        ("59", false),
        ("60", true),
        ("604800", false),
        ("604800", true)
    ])
    func intervalBoundariesAreAccepted(_ text: String, _ repeats: Bool) {
        let model = intervalModel(text: text, repeats: repeats)
        #expect(model.firstInvalidField(now: ProductReminderViewModelFixtures.now) == nil)
    }

    @Test
    func calendarMustBeFutureAndNoMoreThanOneSelectedTimeZoneYearAway() {
        let zone = TimeZone(identifier: "America/Los_Angeles")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let maximum = calendar.date(
            byAdding: .year,
            value: 1,
            to: ProductReminderViewModelFixtures.now
        )!

        #expect(calendarModel(date: ProductReminderViewModelFixtures.now, zone: zone)
            .firstInvalidField(now: ProductReminderViewModelFixtures.now) == .calendarDate)
        #expect(calendarModel(date: maximum, zone: zone)
            .firstInvalidField(now: ProductReminderViewModelFixtures.now) == nil)
        #expect(calendarModel(date: maximum.addingTimeInterval(1), zone: zone)
            .firstInvalidField(now: ProductReminderViewModelFixtures.now) == .calendarDate)
    }

    @Test
    func firstInvalidFieldFocusesWithoutScheduling() async {
        let repository = ProductReminderRepositorySpy()
        let viewModel = makeViewModel(repository: repository)
        viewModel.model = intervalModel(text: "59", repeats: true)

        await viewModel.schedule()

        #expect(viewModel.focusedField == .interval)
        #expect(viewModel.state == .failed(
            model: intervalModel(text: "59", repeats: true),
            error: .invalid(.interval)
        ))
        #expect(await repository.scheduledSelections().isEmpty)
    }

    @Test
    func refreshPublishesTheCurrentSafeStatusWithoutScheduling() async {
        let next = ProductReminderViewModelFixtures.now.addingTimeInterval(300)
        let repository = ProductReminderRepositorySpy(status: .scheduled(nextTriggerDate: next))
        let viewModel = makeViewModel(repository: repository)

        await viewModel.refresh()

        #expect(viewModel.state == .editing(
            model: ProductReminderViewModelFixtures.defaultModel,
            status: .scheduled(nextTriggerDate: next)
        ))
        #expect(await repository.scheduledSelections().isEmpty)
    }

    @Test
    func permissionDenialIsDistinctFromOtherScheduleFailures() async {
        let repository = ProductReminderRepositorySpy(scheduleBehavior: .authorizationDenied)
        let viewModel = makeViewModel(repository: repository)

        await viewModel.schedule()

        #expect(viewModel.state == .failed(
            model: ProductReminderViewModelFixtures.defaultModel,
            error: .authorizationDenied
        ))
    }

    @Test
    func attachmentFallbackWarningRemainsARealSuccess() async {
        let repository = ProductReminderRepositorySpy(
            scheduleBehavior: .result(.scheduledWithWarning(.textOnlyAttachmentFallback))
        )
        let viewModel = makeViewModel(repository: repository)

        await viewModel.schedule()

        #expect(viewModel.state == .scheduled(
            .scheduledWithWarning(.textOnlyAttachmentFallback)
        ))
    }

    @Test
    func validatedIntervalTextIsTheSelectionSentForScheduling() async {
        let repository = ProductReminderRepositorySpy()
        let viewModel = makeViewModel(repository: repository)
        viewModel.model = intervalModel(text: "120", repeats: true)

        await viewModel.schedule()

        #expect(await repository.scheduledSelections() == [
            .interval(seconds: 120, repeats: true)
        ])
    }

    @Test
    func scheduleFailureNeverShowsSuccess() async {
        let repository = ProductReminderRepositorySpy(scheduleBehavior: .failure)
        let viewModel = makeViewModel(repository: repository)

        await viewModel.schedule()

        #expect(viewModel.state == .failed(
            model: ProductReminderViewModelFixtures.defaultModel,
            error: .schedule
        ))
    }

    @Test
    func failedReplacementScheduleKeepsTheRefreshedPendingStatus() async {
        let next = ProductReminderViewModelFixtures.now.addingTimeInterval(900)
        let repository = ProductReminderRepositorySpy(
            status: .scheduled(nextTriggerDate: next),
            scheduleBehavior: .failure
        )
        let viewModel = makeViewModel(repository: repository)

        await viewModel.refresh()
        await viewModel.schedule()

        #expect(viewModel.currentStatus == .scheduled(nextTriggerDate: next))
        #expect(viewModel.state == .failed(
            model: ProductReminderViewModelFixtures.defaultModel,
            error: .schedule
        ))
    }

    @Test
    func cancellationReturnsToEditingWithARefreshedStatus() async {
        let next = ProductReminderViewModelFixtures.now.addingTimeInterval(600)
        let repository = ProductReminderRepositorySpy(
            status: .scheduled(nextTriggerDate: next),
            scheduleBehavior: .cancellation
        )
        let viewModel = makeViewModel(repository: repository)

        await viewModel.schedule()

        #expect(viewModel.state == .editing(
            model: ProductReminderViewModelFixtures.defaultModel,
            status: .scheduled(nextTriggerDate: next)
        ))
        #expect(await repository.statusProductIDs() == [7])
    }

    @Test
    func cancelRemovesOnlyTheSelectedProductAndRefreshesItsStatus() async {
        let repository = ProductReminderRepositorySpy(status: .notScheduled)
        let viewModel = makeViewModel(repository: repository)

        await viewModel.cancel()

        #expect(await repository.cancelledProductIDs() == [7])
        #expect(await repository.statusProductIDs() == [7])
        #expect(viewModel.state == .editing(
            model: ProductReminderViewModelFixtures.defaultModel,
            status: .notScheduled
        ))
    }

    @Test
    func anOlderScheduleCompletionCannotOverwriteANewerEdit() async {
        let repository = ControlledProductReminderRepository()
        let viewModel = makeViewModel(repository: repository)
        let scheduleTask = Task { await viewModel.schedule() }
        await repository.waitUntilScheduling()

        viewModel.model = intervalModel(text: "120", repeats: true)
        await repository.finishScheduling(with: .scheduled)
        await scheduleTask.value

        #expect(viewModel.state == .editing(
            model: intervalModel(text: "120", repeats: true),
            status: .notScheduled
        ))
    }

    private func makeViewModel(
        repository: some IProductReminderRepository
    ) -> ProductReminderViewModel {
        ProductReminderViewModel(
            product: .fixture(id: 7),
            reminders: repository,
            clock: ProductReminderViewModelFixtures.clock
        )
    }

    private func intervalModel(text: String, repeats: Bool) -> ProductReminderModel {
        ProductReminderModel(
            selection: .interval(seconds: 60, repeats: repeats),
            intervalText: text,
            calendarDate: ProductReminderViewModelFixtures.now.addingTimeInterval(3_600),
            calendarTimeZone: ProductReminderViewModelFixtures.zone
        )
    }

    private func calendarModel(date: Date, zone: TimeZone) -> ProductReminderModel {
        ProductReminderModel(
            selection: .calendar(date: date, timeZone: zone),
            intervalText: "60",
            calendarDate: date,
            calendarTimeZone: zone
        )
    }
}

private nonisolated enum ProductReminderViewModelFixtures {
    static let now = Date(timeIntervalSince1970: 1_800_000_000)
    static let zone = TimeZone.current
    static let clock = AppClock(
        now: { now },
        monotonicNow: { ContinuousClock().now },
        sleep: { _ in }
    )
    static let defaultModel = ProductReminderModel(
        selection: .quickTest,
        intervalText: "60",
        calendarDate: now.addingTimeInterval(3_600),
        calendarTimeZone: zone
    )
}

private nonisolated enum ProductReminderScheduleBehavior: Sendable {
    case result(ProductReminderScheduleResult)
    case authorizationDenied
    case cancellation
    case failure
}

private actor ProductReminderRepositorySpy: IProductReminderRepository {
    private let configuredStatus: ProductReminderStatus
    private let scheduleBehavior: ProductReminderScheduleBehavior
    private var selections: [ProductReminderSelection] = []
    private var statusIDs: [Product.ID] = []
    private var cancelledIDs: [Product.ID] = []

    init(
        status: ProductReminderStatus = .notScheduled,
        scheduleBehavior: ProductReminderScheduleBehavior = .result(.scheduled)
    ) {
        configuredStatus = status
        self.scheduleBehavior = scheduleBehavior
    }

    func status(productID: Product.ID) -> ProductReminderStatus {
        statusIDs.append(productID)
        return configuredStatus
    }

    func schedule(
        product: Product,
        selection: ProductReminderSelection
    ) async throws -> ProductReminderScheduleResult {
        _ = product
        selections.append(selection)
        switch scheduleBehavior {
        case let .result(result): return result
        case .authorizationDenied: throw ProductReminderError.authorizationDenied
        case .cancellation: throw CancellationError()
        case .failure: throw ProductReminderTestFailure.schedule
        }
    }

    func remindLater(
        from source: ProductReminderRescheduleSource,
        after delay: Duration
    ) async throws {
        _ = source
        _ = delay
    }

    func cancel(productID: Product.ID) {
        cancelledIDs.append(productID)
    }

    func scheduledSelections() -> [ProductReminderSelection] { selections }
    func statusProductIDs() -> [Product.ID] { statusIDs }
    func cancelledProductIDs() -> [Product.ID] { cancelledIDs }
}

private actor ControlledProductReminderRepository: IProductReminderRepository {
    private var continuation: CheckedContinuation<ProductReminderScheduleResult, Never>?
    private var schedulingWaiters: [CheckedContinuation<Void, Never>] = []

    func status(productID: Product.ID) -> ProductReminderStatus {
        _ = productID
        return .notScheduled
    }

    func schedule(
        product: Product,
        selection: ProductReminderSelection
    ) async throws -> ProductReminderScheduleResult {
        _ = product
        _ = selection
        for waiter in schedulingWaiters { waiter.resume() }
        schedulingWaiters.removeAll()
        return await withCheckedContinuation { continuation = $0 }
    }

    func remindLater(
        from source: ProductReminderRescheduleSource,
        after delay: Duration
    ) async throws {
        _ = source
        _ = delay
    }

    func cancel(productID: Product.ID) { _ = productID }

    func waitUntilScheduling() async {
        if continuation != nil { return }
        await withCheckedContinuation { schedulingWaiters.append($0) }
    }

    func finishScheduling(with result: ProductReminderScheduleResult) {
        continuation?.resume(returning: result)
        continuation = nil
    }
}
