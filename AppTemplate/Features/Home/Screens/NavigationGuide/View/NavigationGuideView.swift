import SwiftUI

struct NavigationGuideView: View {
    @State private var viewModel: NavigationGuideViewModel

    init(router: FlowRouter) {
        _viewModel = State(
            initialValue: NavigationGuideViewModel(router: router)
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
                    viewModel.close()
                }
            }
        }
    }
}
