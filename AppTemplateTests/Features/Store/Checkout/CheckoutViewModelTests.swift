import Testing
@testable import AppTemplate

@MainActor
struct CheckoutViewModelTests {
    @Test
    func fictionalPrefillIsValidAndFieldsCapAtOneHundredUnicodeScalars() {
        var model = CheckoutModel.fictionalPrefill
        model.recipient = String(repeating: "😀", count: 120)
        model.address = String(repeating: "a", count: 101)
        model.note = String(repeating: "n", count: 150)

        #expect(model.recipient.unicodeScalars.count == 100)
        #expect(model.address.unicodeScalars.count == 100)
        #expect(model.note.unicodeScalars.count == 100)
        #expect(CheckoutModel.fictionalPrefill.firstInvalidField() == nil)
    }

    @Test
    func firstInvalidFieldIsDeterministic() {
        let model = CheckoutModel(recipient: " ", address: " ", note: "")
        #expect(model.firstInvalidField() == .recipient)
    }

    @Test
    func deliveryReviewEditSuccessAndDoneSequence() async {
        let repository = CartRepositorySpy(aggregate: .fixture(revision: 7))
        var doneCount = 0
        let viewModel = CheckoutViewModel(cart: .fixture(revision: 7), repository: repository, onDone: { doneCount += 1 }, onRevisionConflict: {})

        viewModel.continueToReview()
        guard case .editing(step: .review, model: _) = viewModel.state else { Issue.record("Expected review"); return }
        viewModel.editDelivery()
        guard case .editing(step: .delivery, model: _) = viewModel.state else { Issue.record("Expected delivery"); return }
        viewModel.continueToReview()
        await viewModel.placeDemoOrder()
        #expect(viewModel.state == .success)
        #expect(doneCount == 0)
        viewModel.done()
        #expect(doneCount == 1)
        #expect(await repository.revisions() == [7])
    }

    @Test
    func checkoutConflictDismissesToCartWithoutFalseSuccess() async {
        let repository = CartRepositorySpy(
            aggregate: .fixture(revision: 10),
            checkoutError: .revisionConflict(expected: 9, actual: 10)
        )
        var conflictCount = 0
        let viewModel = CheckoutViewModel(cart: .fixture(revision: 9), repository: repository, onDone: {}, onRevisionConflict: { conflictCount += 1 })

        viewModel.continueToReview()
        await viewModel.placeDemoOrder()

        #expect(await repository.revisions() == [9])
        #expect(conflictCount == 1)
        #expect(viewModel.state != .success)
    }

    @Test
    func nonConflictFailureRetriesWithLaunchRevision() async {
        let repository = CartRepositorySpy(aggregate: .fixture(revision: 4), checkoutError: .emptyCart)
        let viewModel = CheckoutViewModel(cart: .fixture(revision: 4), repository: repository, onDone: {}, onRevisionConflict: {})
        viewModel.continueToReview()

        await viewModel.placeDemoOrder()
        guard case .failed = viewModel.state else { Issue.record("Expected failure"); return }
        await viewModel.retryPlaceDemoOrder()

        #expect(await repository.revisions() == [4, 4])
    }
}
