import SwiftUI

struct BrowseOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: BrowseOptionsViewModel

    init(preferences: BrowsePreferencesStore) {
        _viewModel = State(
            initialValue: BrowseOptionsViewModel(preferences: preferences)
        )
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(alignment: .leading, spacing: 16) {
            Text("Browse Options")
                .font(.title2)

            Picker("Sort", selection: $viewModel.sortOrder) {
                Text("Title (A–Z)")
                    .tag(BrowseSortOrder.titleAscending)
                Text("Title (Z–A)")
                    .tag(BrowseSortOrder.titleDescending)
            }

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
