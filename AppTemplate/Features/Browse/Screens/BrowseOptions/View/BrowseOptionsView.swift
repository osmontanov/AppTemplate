import SwiftUI

struct BrowseOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: BrowseOptionsViewModel

    init() {
        _viewModel = State(initialValue: BrowseOptionsViewModel())
    }

    var body: some View {
        AdaptiveContentContainer {
            VStack(alignment: .leading, spacing: 16) {
                Text("Browse Options")
                    .font(.title2)

                Text("This template uses static Browse examples while preserving the Options sheet.")
                    .foregroundStyle(.secondary)

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
