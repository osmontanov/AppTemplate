import SwiftUI

struct SessionInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SessionInfoViewModel

    init(sessionStore: SessionStore) {
        _viewModel = State(
            initialValue: SessionInfoViewModel(sessionStore: sessionStore)
        )
    }

    var body: some View {
        Form {
            Section("Session") {
                LabeledContent("Status", value: viewModel.status)

                if let displayName = viewModel.displayName {
                    LabeledContent("Name", value: displayName)
                }

                if let failureMessage = viewModel.failureMessage {
                    Text(failureMessage)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}
