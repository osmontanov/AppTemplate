nonisolated
enum StorePresentation: Identifiable, Hashable, Sendable {
    case filters
    case authentication
    case checkout
    case reminder(Int)

    var id: String {
        switch self {
        case .filters: "store.presentation.filters"
        case .authentication: "store.presentation.authentication"
        case .checkout: "store.presentation.checkout"
        case let .reminder(productID): "store.presentation.reminder.\(productID)"
        }
    }
}
