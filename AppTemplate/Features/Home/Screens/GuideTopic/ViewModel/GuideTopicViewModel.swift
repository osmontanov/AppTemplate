import Observation

@MainActor
@Observable
final class GuideTopicViewModel {
    let id: NavigationGuideItem.ID

    init(id: NavigationGuideItem.ID) {
        self.id = id
    }
}
