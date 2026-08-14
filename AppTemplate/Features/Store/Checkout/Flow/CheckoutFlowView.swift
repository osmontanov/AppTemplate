import SwiftUI

struct CheckoutFlowView: View {
    @State private var viewModel: CheckoutViewModel
    @FocusState private var focusedField: CheckoutField?

    init(
        cart: CartAggregate,
        repository: any ICartRepository,
        onDone: @escaping () -> Void,
        onRevisionConflict: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: CheckoutViewModel(
            cart: cart,
            repository: repository,
            onDone: onDone,
            onRevisionConflict: onRevisionConflict
        ))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case let .editing(step: .delivery, model: model):
                    delivery(model)
                case let .editing(step: .review, model: model):
                    review(model, failed: false)
                case let .failed(model):
                    review(model, failed: true)
                case let .submitting(model):
                    review(model, failed: false).disabled(true).overlay { ProgressView() }
                case .success, .editing(step: .success, model: _):
                    success
                }
            }
            .navigationTitle(StoreServicesText.resource("Demo checkout"))
        }
        .onChange(of: viewModel.invalidField) { _, field in focusedField = field }
        .frame(minWidth: 360, minHeight: 420)
        .accessibilityIdentifier("screen.store.checkout")
    }

    private func delivery(_ model: CheckoutModel) -> some View {
        Form {
            Section(StoreServicesText.resource("Fictional delivery")) {
                TextField(StoreServicesText.resource("Recipient"), text: modelBinding(model, keyPath: \.recipient))
                    .focused($focusedField, equals: .recipient)
                TextField(StoreServicesText.resource("Address"), text: modelBinding(model, keyPath: \.address))
                    .focused($focusedField, equals: .address)
                TextField(StoreServicesText.resource("Note"), text: modelBinding(model, keyPath: \.note))
                    .focused($focusedField, equals: .note)
            }
            Section {
                Text(StoreServicesText.resource("No payment or network request is made.")).foregroundStyle(.secondary)
                Button(StoreServicesText.resource("Review order")) { viewModel.continueToReview() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canContinue)
            }
        }
    }

    private func review(_ model: CheckoutModel, failed: Bool) -> some View {
        Form {
            Section(StoreServicesText.resource("Delivery")) {
                LabeledContent(StoreServicesText.resource("Recipient"), value: model.recipient)
                LabeledContent(StoreServicesText.resource("Address"), value: model.address)
                if !model.note.isEmpty { LabeledContent(StoreServicesText.resource("Note"), value: model.note) }
            }
            if failed {
                Text(StoreServicesText.resource("The demo order could not be placed. You can retry safely."))
                    .foregroundStyle(.red)
            }
            Section {
                Button(StoreServicesText.resource("Edit delivery")) { viewModel.editDelivery() }
                Button(failed
                    ? StoreServicesText.string("Retry demo order")
                    : StoreServicesText.string("Place demo order")) {
                    Task {
                        if failed { await viewModel.retryPlaceDemoOrder() }
                        else { await viewModel.placeDemoOrder() }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var success: some View {
        ContentUnavailableView {
            Label(StoreServicesText.resource("Demo order placed"), systemImage: "checkmark.circle.fill")
        } description: {
            Text(StoreServicesText.resource("This was a fictional local checkout."))
        } actions: {
            Button(StoreServicesText.resource("Done")) { viewModel.done() }.buttonStyle(.borderedProminent)
        }
    }

    private func modelBinding(
        _ model: CheckoutModel,
        keyPath: WritableKeyPath<CheckoutModel, String>
    ) -> Binding<String> {
        Binding(
            get: { model[keyPath: keyPath] },
            set: { value in
                var updated = model
                updated[keyPath: keyPath] = value
                viewModel.update(updated)
            }
        )
    }
}
