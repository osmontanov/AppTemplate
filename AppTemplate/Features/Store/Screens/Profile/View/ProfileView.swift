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
            Picker(StoreServicesText.resource("Profile section"), selection: Binding(
                get: { viewModel.selectedSection },
                set: { select($0) }
            )) {
                Text(StoreServicesText.resource("Overview")).tag(ProfileSection.overview)
                Text(StoreServicesText.resource("Preferences")).tag(ProfileSection.preferences)
                Text(StoreServicesText.resource("About")).tag(ProfileSection.about)
                Text(StoreServicesText.resource("Account"))
                    .accessibilityIdentifier("action.store.profile.account")
                    .tag(ProfileSection.account)
            }
            .pickerStyle(.segmented)

            switch viewModel.selectedSection {
            case .overview:
                if case let .authenticated(profile, _) = session.presentation.state {
                    Text(StoreServicesText.resource("Welcome, \(profile.firstName) \(profile.lastName)"))
                } else {
                    Text(StoreServicesText.resource("You are browsing as a guest.")).foregroundStyle(.secondary)
                }
            case .preferences:
                StorePreferencesForm(repository: preferences)
            case .about:
                if let model = viewModel.model {
                    LabeledContent(StoreServicesText.resource("Name"), value: model.displayName)
                    LabeledContent(StoreServicesText.resource("Version"), value: model.version)
                }
            case .account:
                accountContent
            }
        }
        .navigationTitle(StoreServicesText.resource("Profile"))
        .task { await viewModel.load() }
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityIdentifier(AppAccessibilityIdentifier.screen(.profile))
        }
    }

    @ViewBuilder
    private var accountContent: some View {
        if let account = router.cachedAccountPresentation {
            LabeledContent(StoreServicesText.resource("Account"), value: account.displayName)
            Button(StoreServicesText.resource("Sign Out")) {
                Task {
                    await viewModel.signOut()
                    AccessibilityNotification.Announcement(
                        viewModel.error == nil
                            ? StoreServicesText.string("Signed out")
                            : StoreServicesText.string("Sign out failed")
                    ).post()
                }
            }
                .frame(minHeight: 44)
                .accessibilityIdentifier(AppAccessibilityIdentifier.action(.signOut))
            if viewModel.error == .signOutDeletionFailed {
                Label(
                    StoreServicesText.resource("The saved session could not be removed."),
                    systemImage: "exclamationmark.triangle.fill"
                )
                    .foregroundStyle(.red)
                    .accessibilityIdentifier(AppAccessibilityIdentifier.result(.actualFailure))
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
