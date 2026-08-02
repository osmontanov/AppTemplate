import SwiftUI

struct GuideTopicView: View {
    @State private var viewModel: GuideTopicViewModel

    init(id: NavigationGuideItem.ID) {
        _viewModel = State(initialValue: GuideTopicViewModel(id: id))
    }

    var body: some View {
        AdaptiveContentContainer {
            VStack(spacing: 16) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.largeTitle)
                    .accessibilityHidden(true)
                Text(verbatim: viewModel.id)
                    .font(.title)
            }
        }
        .navigationTitle("Guide Topic")
    }
}
