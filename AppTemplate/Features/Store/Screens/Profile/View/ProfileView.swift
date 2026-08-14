import SwiftUI

struct ProfileView: View {
    @Bindable var router: StoreRouter
    let session: any ISessionActions
    let preferences: any IStorePreferencesRepository
    @State private var viewModel: ProfileViewModel

    init(
        router: StoreRouter,
        session: any ISessionActions,
        appInfo: any IAppInfoService,
        preferences: any IStorePreferencesRepository
    ) {
        self.router = router
        self.session = session
        self.preferences = preferences
        _viewModel = State(initialValue: ProfileViewModel(
            router: router,
            session: session,
            appInfo: appInfo
        ))
    }

    var body: some View {
        Form {
            Picker("Profile section", selection: Binding(
                get: { viewModel.selectedSection },
                set: { select($0) }
            )) {
                Text("Overview").tag(ProfileSection.overview)
                Text("Preferences").tag(ProfileSection.preferences)
                Text("About").tag(ProfileSection.about)
                Text("Account").tag(ProfileSection.account)
            }
            .pickerStyle(.segmented)

            switch viewModel.selectedSection {
            case .overview:
                if case let .authenticated(profile, _) = session.presentation.state {
                    Text("Welcome, \(profile.firstName) \(profile.lastName)")
                } else {
                    Text("You are browsing as a guest.").foregroundStyle(.secondary)
                }
            case .preferences:
                StorePreferencesForm(repository: preferences)
            case .about:
                if let model = viewModel.model {
                    LabeledContent("Name", value: model.displayName)
                    LabeledContent("Version", value: model.version)
                }
            case .account:
                accountContent
            }
        }
        .navigationTitle("Profile")
        .task { await viewModel.load() }
        .accessibilityIdentifier("screen.store.profile")
    }

    @ViewBuilder
    private var accountContent: some View {
        if let account = router.cachedAccountPresentation {
            LabeledContent("Account", value: account.displayName)
            Button("Sign Out") { Task { await viewModel.signOut() } }
            if viewModel.error == .signOutDeletionFailed {
                Text("The saved session could not be removed.")
                    .foregroundStyle(.red)
            }
        }
    }

    private func select(_ section: ProfileSection) {
        let resolution = viewModel.select(section, session: session.presentation.state)
        if case let .blocked(reason) = resolution {
            router.presentation = .sessionRecovery(reason)
        }
    }
}
