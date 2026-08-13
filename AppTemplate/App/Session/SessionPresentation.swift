nonisolated struct SessionPresentation: Equatable, Sendable {
    let state: SessionState
    let revision: UInt64
}

nonisolated struct SessionStatusPresentation: Equatable, Sendable {
    let session: SessionPresentation
    let expiry: SessionExpiryPresentation?
}
