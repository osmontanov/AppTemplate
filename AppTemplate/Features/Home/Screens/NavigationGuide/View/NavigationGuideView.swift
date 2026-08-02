import SwiftUI

struct NavigationGuideView: View {
    private struct TopicRow: Identifiable {
        let id: String
        let title: LocalizedStringResource
        let systemImage: String
    }

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
            ForEach(topicRows) { row in
                Button {
                    viewModel.openTopic(id: row.id)
                } label: {
                    Label(row.title, systemImage: row.systemImage)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Navigation Guide")
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

    private let topicRows = [
        TopicRow(
            id: "screen-owned-routes",
            title: "Screen-owned routes",
            systemImage: "list.bullet.rectangle"
        ),
        TopicRow(
            id: "independent-flows",
            title: "Independent flows",
            systemImage: "square.3.layers.3d"
        ),
        TopicRow(
            id: "scene-restoration",
            title: "Scene restoration",
            systemImage: "arrow.clockwise"
        )
    ]
}
