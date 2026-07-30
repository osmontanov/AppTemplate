import SwiftUI

struct SessionInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = SessionInfoViewModel()

    var body: some View {
        Form {
            Section("Session") {
                Text("Add product-specific session details here if needed.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}
