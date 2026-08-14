import SwiftUI

struct CheckoutFlowView: View {
    @State private var viewModel: CheckoutViewModel
    @FocusState private var focusedField: CheckoutField?
    @AccessibilityFocusState private var accessibilityFocusedField: CheckoutField?
    @AccessibilityFocusState private var resultIsFocused: Bool
    @Environment(\.dismiss) private var dismiss

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
                    review(model, failed: false).disabled(true).overlay {
                        ProgressView()
                            .accessibilityLabel(StoreServicesText.resource("Placing demo order"))
                            .accessibilityIdentifier(AppAccessibilityIdentifier.result(.loading))
                    }
                case .success, .editing(step: .success, model: _):
                    success
                }
            }
            .navigationTitle(StoreServicesText.resource("Demo checkout"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(StoreServicesText.resource("Cancel")) { dismiss() }
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier(AppAccessibilityIdentifier.action(.cancel))
                }
            }
        }
        .onChange(of: viewModel.invalidField) { _, field in
            focusedField = field
            accessibilityFocusedField = field
        }
        .frame(minWidth: 360, minHeight: 420)
        .accessibilityIdentifier(AppAccessibilityIdentifier.screen(.checkout))
    }

    private func delivery(_ model: CheckoutModel) -> some View {
        Form {
            Section(StoreServicesText.resource("Fictional delivery")) {
                TextField(StoreServicesText.resource("Recipient"), text: modelBinding(model, keyPath: \.recipient))
                    .focused($focusedField, equals: .recipient)
                    .accessibilityFocused($accessibilityFocusedField, equals: .recipient)
                TextField(StoreServicesText.resource("Address"), text: modelBinding(model, keyPath: \.address))
                    .focused($focusedField, equals: .address)
                    .accessibilityFocused($accessibilityFocusedField, equals: .address)
                TextField(StoreServicesText.resource("Note"), text: modelBinding(model, keyPath: \.note))
                    .focused($focusedField, equals: .note)
                    .accessibilityFocused($accessibilityFocusedField, equals: .note)
            }
            Section {
                Text(StoreServicesText.resource("No payment or network request is made.")).foregroundStyle(.secondary)
                Button(StoreServicesText.resource("Review order")) { viewModel.continueToReview() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canContinue)
                    .frame(minHeight: 44)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier(AppAccessibilityIdentifier.action(.continueCheckout))
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
                Label(
                    StoreServicesText.resource("The demo order could not be placed. You can retry safely."),
                    systemImage: "exclamationmark.triangle.fill"
                )
                    .foregroundStyle(.red)
                    .accessibilityFocused($resultIsFocused)
                    .accessibilityIdentifier(AppAccessibilityIdentifier.result(.actualFailure))
            }
            Section {
                Button(StoreServicesText.resource("Edit delivery")) { viewModel.editDelivery() }
                Button(failed
                    ? StoreServicesText.string("Retry demo order")
                    : StoreServicesText.string("Place demo order")) {
                    Task {
                        if failed { await viewModel.retryPlaceDemoOrder() }
                        else { await viewModel.placeDemoOrder() }
                        resultIsFocused = true
                        AccessibilityNotification.Announcement(
                            StoreServicesText.string("Checkout status updated")
                        ).post()
                    }
                }
                .buttonStyle(.borderedProminent)
                .frame(minHeight: 44)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var success: some View {
        ContentUnavailableView {
            Label(StoreServicesText.resource("Demo order placed"), systemImage: "checkmark.circle.fill")
        } description: {
            Text(StoreServicesText.resource("This was a fictional local checkout."))
        } actions: {
            Button(StoreServicesText.resource("Done")) { viewModel.done() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .accessibilityFocused($resultIsFocused)
        .accessibilityIdentifier(AppAccessibilityIdentifier.result(.actualSuccess))
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
