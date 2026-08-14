nonisolated
enum StorePresentation: Identifiable, Hashable, Sendable {
    case filters
    case authentication
    case checkout
    case reminder(Int)
    case sessionRecovery(SessionUnavailableReason)

    var id: String {
        switch self {
        case .filters: "store.presentation.filters"
        case .authentication: "store.presentation.authentication"
        case .checkout: "store.presentation.checkout"
        case let .reminder(productID): "store.presentation.reminder.\(productID)"
        case let .sessionRecovery(reason):
            switch reason {
            case .secureStorageReadFailed:
                "store.presentation.session-recovery.read"
            case .secureStorageCleanupFailed:
                "store.presentation.session-recovery.cleanup"
            }
        }
    }
}
