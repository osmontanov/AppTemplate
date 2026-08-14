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
            .navigationTitle("Demo checkout")
        }
        .onChange(of: viewModel.invalidField) { _, field in focusedField = field }
        .frame(minWidth: 360, minHeight: 420)
        .accessibilityIdentifier("screen.store.checkout")
    }

    private func delivery(_ model: CheckoutModel) -> some View {
        Form {
            Section("Fictional delivery") {
                TextField("Recipient", text: modelBinding(model, keyPath: \.recipient))
                    .focused($focusedField, equals: .recipient)
                TextField("Address", text: modelBinding(model, keyPath: \.address))
                    .focused($focusedField, equals: .address)
                TextField("Note", text: modelBinding(model, keyPath: \.note))
                    .focused($focusedField, equals: .note)
            }
            Section {
                Text("No payment or network request is made.").foregroundStyle(.secondary)
                Button("Review order") { viewModel.continueToReview() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canContinue)
            }
        }
    }

    private func review(_ model: CheckoutModel, failed: Bool) -> some View {
        Form {
            Section("Delivery") {
                LabeledContent("Recipient", value: model.recipient)
                LabeledContent("Address", value: model.address)
                if !model.note.isEmpty { LabeledContent("Note", value: model.note) }
            }
            if failed {
                Text("The demo order could not be placed. You can retry safely.")
                    .foregroundStyle(.red)
            }
            Section {
                Button("Edit delivery") { viewModel.editDelivery() }
                Button(failed ? "Retry demo order" : "Place demo order") {
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
            Label("Demo order placed", systemImage: "checkmark.circle.fill")
        } description: {
            Text("This was a fictional local checkout.")
        } actions: {
            Button("Done") { viewModel.done() }.buttonStyle(.borderedProminent)
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
