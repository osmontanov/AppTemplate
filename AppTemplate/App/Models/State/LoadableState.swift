nonisolated enum LoadableState<
    Content: Equatable & Sendable,
    Failure: Equatable & Sendable
>: Equatable, Sendable {
    case idle
    case loading
    case content(Content)
    case empty
    case failed(Failure)
}
