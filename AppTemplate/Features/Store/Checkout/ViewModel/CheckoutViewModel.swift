import Observation

@MainActor
@Observable
final class CheckoutViewModel {
    private let expectedRevision: Int64
    private let repository: any ICartRepository
    private let onDone: () -> Void
    private let onRevisionConflict: () -> Void
    private let cartWasEmpty: Bool

    private(set) var state: CheckoutState
    private(set) var invalidField: CheckoutField?

    var canContinue: Bool {
        guard case let .editing(step: .delivery, model: model) = state else { return false }
        return !cartWasEmpty && model.firstInvalidField() == nil
    }

    init(
        cart: CartAggregate,
        repository: any ICartRepository,
        onDone: @escaping () -> Void,
        onRevisionConflict: @escaping () -> Void
    ) {
        expectedRevision = cart.revision
        self.repository = repository
        self.onDone = onDone
        self.onRevisionConflict = onRevisionConflict
        cartWasEmpty = cart.lines.isEmpty
        state = .editing(step: .delivery, model: .fictionalPrefill)
    }

    func update(_ model: CheckoutModel) {
        guard case .editing(step: .delivery, model: _) = state else { return }
        state = .editing(step: .delivery, model: model)
    }

    func continueToReview() {
        guard !cartWasEmpty,
              case let .editing(step: .delivery, model: model) = state
        else { return }
        if let field = model.firstInvalidField() {
            invalidField = field
            return
        }
        invalidField = nil
        state = .editing(step: .review, model: model)
    }

    func editDelivery() {
        switch state {
        case let .editing(step: .review, model: model), let .failed(model):
            state = .editing(step: .delivery, model: model)
        default:
            break
        }
    }

    func placeDemoOrder() async {
        guard case let .editing(step: .review, model: model) = state else { return }
        await submit(model)
    }

    func retryPlaceDemoOrder() async {
        guard case let .failed(model) = state else { return }
        await submit(model)
    }

    func done() {
        guard state == .success else { return }
        onDone()
    }

    private func submit(_ model: CheckoutModel) async {
        state = .submitting(model)
        do {
            try await repository.checkout(expectedRevision: expectedRevision)
            state = .success
        } catch let error as CartRepositoryError {
            if case .revisionConflict = error {
                state = .editing(step: .review, model: model)
                onRevisionConflict()
            } else {
                state = .failed(model)
            }
        } catch {
            state = .failed(model)
        }
    }
}
