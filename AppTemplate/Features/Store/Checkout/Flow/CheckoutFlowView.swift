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
                            .accessibilityLabel(AppText.resource("Placing demo order"))
                            .accessibilityIdentifier(AppAccessibilityIdentifier.result(.loading))
                    }
                case .success, .editing(step: .success, model: _):
                    success
                }
            }
            .navigationTitle(AppText.resource("Demo checkout"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppText.resource("Cancel")) { dismiss() }
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
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityIdentifier(AppAccessibilityIdentifier.screen(.checkout))
        }
    }

    private func delivery(_ model: CheckoutModel) -> some View {
        Form {
            Section(AppText.resource("Fictional delivery")) {
                TextField(AppText.resource("Recipient"), text: modelBinding(model, keyPath: \.recipient))
                    .focused($focusedField, equals: .recipient)
                    .accessibilityFocused($accessibilityFocusedField, equals: .recipient)
                TextField(AppText.resource("Address"), text: modelBinding(model, keyPath: \.address))
                    .focused($focusedField, equals: .address)
                    .accessibilityFocused($accessibilityFocusedField, equals: .address)
                TextField(AppText.resource("Note"), text: modelBinding(model, keyPath: \.note))
                    .focused($focusedField, equals: .note)
                    .accessibilityFocused($accessibilityFocusedField, equals: .note)
            }
            Section {
                Text(AppText.resource("No payment or network request is made.")).foregroundStyle(.secondary)
                Button(AppText.resource("Review order")) { viewModel.continueToReview() }
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
            Section(AppText.resource("Delivery")) {
                LabeledContent(AppText.resource("Recipient"), value: model.recipient)
                LabeledContent(AppText.resource("Address"), value: model.address)
                if !model.note.isEmpty { LabeledContent(AppText.resource("Note"), value: model.note) }
            }
            if failed {
                Label(
                    AppText.resource("The demo order could not be placed. You can retry safely."),
                    systemImage: "exclamationmark.triangle.fill"
                )
                    .foregroundStyle(.red)
                    .accessibilityFocused($resultIsFocused)
                    .accessibilityIdentifier(AppAccessibilityIdentifier.result(.actualFailure))
            }
            Section {
                Button(AppText.resource("Edit delivery")) { viewModel.editDelivery() }
                Button(failed
                    ? AppText.string("Retry demo order")
                    : AppText.string("Place demo order")) {
                    Task {
                        if failed { await viewModel.retryPlaceDemoOrder() }
                        else { await viewModel.placeDemoOrder() }
                        resultIsFocused = true
                        AccessibilityNotification.Announcement(
                            AppText.string("Checkout status updated")
                        ).post()
                    }
                }
                .buttonStyle(.borderedProminent)
                .frame(minHeight: 44)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("action.store.checkout.place")
            }
        }
    }

    private var success: some View {
        ContentUnavailableView {
            Label(AppText.resource("Demo order placed"), systemImage: "checkmark.circle.fill")
        } description: {
            Text(AppText.resource("This was a fictional local checkout."))
        } actions: {
            Button(AppText.resource("Done")) { viewModel.done() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("action.store.checkout.done")
        }
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityFocused($resultIsFocused)
                .accessibilityIdentifier(AppAccessibilityIdentifier.result(.actualSuccess))
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
