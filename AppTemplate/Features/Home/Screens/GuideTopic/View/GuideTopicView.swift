import SwiftUI

struct GuideTopicView: View {
    @State private var viewModel: GuideTopicViewModel

    init(id: NavigationGuideItem.ID) {
        _viewModel = State(initialValue: GuideTopicViewModel(id: id))
    }

    var body: some View {
        Group {
            if let item = viewModel.item {
                VStack(spacing: 16) {
                    Image(systemName: item.systemImage)
                        .font(.largeTitle)
                    Text(item.title)
                        .font(.title)
                }
            } else {
                EmptyStateView(
                    title: "Topic unavailable",
                    systemImage: "exclamationmark.triangle",
                    message: "This guide topic is no longer available."
                )
            }
        }
        .padding()
        .navigationTitle(viewModel.item?.title ?? "Guide Topic")
    }
}
