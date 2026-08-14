import Observation

@MainActor
@Observable
final class StoreRouter {
    var path: [StoreRoute]
    var presentation: StorePresentation?
    private(set) var pendingProtectedAction: ProtectedStoreAction?
    private(set) var lastAppliedSessionRevision: UInt64?
    private(set) var profileSection: ProfileSection = .overview
    private(set) var cachedAccountPresentation: ProfileAccountPresentation?

    private var lastIdentity: SessionIdentity = .unknown

    init(path: [StoreRoute] = []) {
        self.path = path
    }

    func push(_ route: StoreRoute) { path.append(route) }

    func replace(with route: StoreRoute) { path = [route] }

    func requestProtected(
        _ action: ProtectedStoreAction,
        session: SessionState
    ) -> ProtectedActionResolution {
        switch session {
        case .restoring:
            preconditionFailure(
                "Protected actions cannot be requested while session is restoring."
            )
        case .guest:
            pendingProtectedAction = action
            presentation = .authentication
            return .presentAuthentication
        case let .unavailable(reason):
            pendingProtectedAction = nil
            if presentation == .authentication {
                presentation = nil
            }
            return .blocked(reason)
        case .authenticated:
            return .execute(action)
        }
    }

    func cancelAuthentication() {
        pendingProtectedAction = nil
        if presentation == .authentication {
            presentation = nil
        }
    }

    func selectProfileSection(
        _ section: ProfileSection,
        session: SessionState
    ) -> ProtectedActionResolution? {
        guard section == .account else {
            profileSection = section
            return nil
        }

        let resolution = requestProtected(.openAccount, session: session)
        guard case .execute = resolution else {
            return resolution
        }
        profileSection = .account
        return nil
    }

    func cacheAccountPresentation(_ value: ProfileAccountPresentation) {
        cachedAccountPresentation = value
    }

    func resetAccountPresentation() {
        profileSection = .overview
        cachedAccountPresentation = nil
    }

    func reconcile(
        _ presentation: SessionPresentation
    ) -> ProtectedStoreAction? {
        guard lastAppliedSessionRevision.map({ presentation.revision > $0 })
                ?? true else {
            return nil
        }
        lastAppliedSessionRevision = presentation.revision

        switch presentation.state {
        case .restoring:
            return nil
        case .guest, .unavailable:
            lastIdentity = .notAuthenticated
            pruneProtectedState()
            return nil
        case let .authenticated(profile, _):
            switch lastIdentity {
            case .unknown:
                lastIdentity = .authenticated(profile.id)
                return nil
            case .notAuthenticated:
                lastIdentity = .authenticated(profile.id)
                if self.presentation == .authentication {
                    self.presentation = nil
                }
                let action = pendingProtectedAction
                pendingProtectedAction = nil
                return action
            case let .authenticated(userID) where userID == profile.id:
                return nil
            case .authenticated:
                pruneProtectedState()
                lastIdentity = .authenticated(profile.id)
                return nil
            }
        }
    }

    func reset() {
        path.removeAll()
        presentation = nil
        pendingProtectedAction = nil
        resetAccountPresentation()
    }

    private func pruneProtectedState() {
        path.removeAll { $0 == .favorites }
        pendingProtectedAction = nil
        if presentation == .authentication {
            presentation = nil
        }
        resetAccountPresentation()
    }

    private enum SessionIdentity: Equatable {
        case unknown
        case notAuthenticated
        case authenticated(Int)
    }
}
