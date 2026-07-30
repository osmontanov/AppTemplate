import Observation

@MainActor
@Observable
final class RelatedItemDetailViewModel {
    let id: BrowseItem.ID

    init(id: BrowseItem.ID) {
        self.id = id
    }
}
