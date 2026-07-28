import SwiftUI

struct NavigationGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: NavigationGuideViewModel

    init() {
        _viewModel = State(
            initialValue: NavigationGuideViewModel()
        )
    }

    var body: some View {
        List(viewModel.items) { item in
            Label(item.title, systemImage: item.systemImage)
        }
        .navigationTitle(viewModel.title)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}
