import SwiftUI

struct NavigationGuideView: View {
    private let router: FlowRouter
    @State private var viewModel: NavigationGuideViewModel

    init(router: FlowRouter) {
        self.router = router
        _viewModel = State(
            initialValue: NavigationGuideViewModel(router: router)
        )
    }

    var body: some View {
        List {
            ForEach(viewModel.items) { item in
                Button {
                    viewModel.openTopic(id: item.id)
                } label: {
                    Label(item.title, systemImage: item.systemImage)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(viewModel.title)
        .navigationDestination(for: NavigationGuideRoute.self) { route in
            switch route {
            case let .topic(id):
                GuideTopicView(id: id)
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    viewModel.close()
                }
            }
        }
    }
}
