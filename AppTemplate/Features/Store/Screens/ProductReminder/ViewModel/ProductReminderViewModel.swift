import Foundation
import Observation

@MainActor
@Observable
final class ProductReminderViewModel {
    private let product: Product
    private let reminders: any IProductReminderRepository
    private let clock: AppClock
    private var draft: ProductReminderModel
    private var lastStatus: ProductReminderStatus = .notScheduled
    private var generation: UInt64 = 0

    private(set) var state: ProductReminderState
    var focusedField: ProductReminderField?
    var currentStatus: ProductReminderStatus { lastStatus }

    var model: ProductReminderModel {
        get { draft }
        set {
            _ = advanceGeneration()
            draft = newValue
            focusedField = nil
            state = .editing(model: newValue, status: lastStatus)
        }
    }

    init(
        product: Product,
        reminders: any IProductReminderRepository,
        clock: AppClock
    ) {
        self.product = product
        self.reminders = reminders
        self.clock = clock
        let model = ProductReminderModel(
            selection: .quickTest,
            intervalText: "60",
            calendarDate: clock.now().addingTimeInterval(3_600),
            calendarTimeZone: .current
        )
        draft = model
        state = .editing(model: model, status: .notScheduled)
    }

    func refresh() async {
        let currentGeneration = advanceGeneration()
        let status = await reminders.status(productID: product.id)
        guard !Task.isCancelled, generation == currentGeneration else { return }
        lastStatus = status
        state = .editing(model: draft, status: status)
    }

    func schedule() async {
        let currentGeneration = advanceGeneration()
        let model = draft
        if let field = model.firstInvalidField(now: clock.now()) {
            guard generation == currentGeneration else { return }
            focusedField = field
            state = .failed(model: model, error: .invalid(field))
            return
        }

        focusedField = nil
        state = .scheduling(model)
        do {
            let result = try await reminders.schedule(
                product: product,
                selection: model.selectionForScheduling()
            )
            try Task.checkCancellation()
            guard generation == currentGeneration else { return }
            lastStatus = .scheduled(nextTriggerDate: nil)
            state = .scheduled(result)
        } catch is CancellationError {
            let status = await reminders.status(productID: product.id)
            guard generation == currentGeneration else { return }
            lastStatus = status
            state = .editing(model: model, status: status)
        } catch ProductReminderError.authorizationDenied {
            guard generation == currentGeneration else { return }
            state = .failed(model: model, error: .authorizationDenied)
        } catch {
            guard generation == currentGeneration else { return }
            state = .failed(model: model, error: .schedule)
        }
    }

    func cancel() async {
        let currentGeneration = advanceGeneration()
        await reminders.cancel(productID: product.id)
        guard !Task.isCancelled, generation == currentGeneration else { return }
        let status = await reminders.status(productID: product.id)
        guard !Task.isCancelled, generation == currentGeneration else { return }
        lastStatus = status
        state = .editing(model: draft, status: status)
    }

    @discardableResult
    private func advanceGeneration() -> UInt64 {
        precondition(generation < UInt64.max, "Product reminder operation generation exhausted")
        generation += 1
        return generation
    }
}
