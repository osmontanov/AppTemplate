import Observation

@MainActor
@Observable
final class GuideTopicViewModel {
    let id: NavigationGuideItem.ID

    var item: NavigationGuideItem? {
        NavigationGuideModel.items.first { $0.id == id }
    }

    init(id: NavigationGuideItem.ID) {
        self.id = id
    }
}
