import Foundation
import Observation

@MainActor
@Observable
final class ProfileViewModel {
    private let router: StoreRouter
    private let session: any ISessionActions
    private let appInfo: any IAppInfoService
    private(set) var state: ProfileState = .idle
    private(set) var model: ProfileModel?
    private(set) var error: ProfileError?

    var selectedSection: ProfileSection { router.profileSection }

    init(
        router: StoreRouter,
        session: any ISessionActions,
        appInfo: any IAppInfoService
    ) {
        self.router = router
        self.session = session
        self.appInfo = appInfo
    }

    func load() async {
        model = ProfileModel(
            displayName: appInfo.displayName,
            version: appInfo.version
        )
        state = .loaded
    }

    func select(
        _ section: ProfileSection,
        session sessionState: SessionState
    ) -> ProtectedActionResolution? {
        let resolution = router.selectProfileSection(
            section,
            session: sessionState
        )
        if section == .account,
           resolution == nil,
           case let .authenticated(profile, availability) = sessionState {
            router.cacheAccountPresentation(ProfileAccountPresentation(
                userID: profile.id,
                displayName: "\(profile.firstName) \(profile.lastName)"
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                availability: availability
            ))
        }
        return resolution
    }

    func signOut() async {
        switch await session.signOut() {
        case .deletionFailed:
            error = .signOutDeletionFailed
        case .cancelled, .guest:
            error = nil
        }
    }
}
