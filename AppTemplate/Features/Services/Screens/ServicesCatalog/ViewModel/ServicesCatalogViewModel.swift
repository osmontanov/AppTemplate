import Foundation

@MainActor
enum ServicesCatalogViewModel {
    static let items: [ServicesCatalogItem] = [
        ServicesCatalogItem(
            route: .appState,
            guide: ServiceLabGuide(
                why: AppText.string("See how persisted application policy selects the visible root while each window keeps its own navigation."),
                preset: AppText.string("The lab uses the running app state, session, and this window's navigation checkpoint."),
                expected: AppText.string("Application-wide commands update policy or session once; window commands affect only this window.")
            )
        ),
        ServicesCatalogItem(
            route: .appInfo,
            guide: ServiceLabGuide(
                why: AppText.string("Read product identity from one app-owned service so Store, Settings, and Services agree."),
                preset: AppText.string("Display name and version come from the retained application dependency; platform comes from the view."),
                expected: AppText.string("The displayed identity matches the rest of the app without creating another bundle reader.")
            )
        ),
        ServicesCatalogItem(
            route: .userDefaults,
            guide: ServiceLabGuide(
                why: AppText.string("Practice scoped preference persistence without coupling screens to global defaults."),
                preset: AppText.string("This guided lab will use isolated demo values."),
                expected: AppText.string("A later task will add safe read, write, and reset controls.")
            )
        ),
        ServicesCatalogItem(
            route: .keychain,
            guide: ServiceLabGuide(
                why: AppText.string("Explore secure storage through a narrow service boundary."),
                preset: AppText.string("This guided lab will use a dedicated demo key."),
                expected: AppText.string("A later task will add bounded secure-storage operations.")
            )
        ),
        ServicesCatalogItem(
            route: .localDatabase,
            guide: ServiceLabGuide(
                why: AppText.string("Learn typed local persistence without exposing the database implementation to the view."),
                preset: AppText.string("The Basic preset uses three bounded ExampleRecord values and lookahead-backed paging."),
                expected: AppText.string("Create, update, upsert, batch, search, paging, delete, and reset stay behind the typed repository facade.")
            )
        ),
        ServicesCatalogItem(
            route: .remoteAPI,
            guide: ServiceLabGuide(
                why: AppText.string("Observe a remote request through a safe, diagnostic service facade."),
                preset: AppText.string("The Basic preset runs bounded product search; Advanced adds fixed product, diagnostic, and semantic session actions."),
                expected: AppText.string("Only allowlisted diagnostics and safe results are visible; credentials and tokens never cross the session boundary.")
            )
        ),
        ServicesCatalogItem(
            route: .localNotifications,
            guide: ServiceLabGuide(
                why: AppText.string("Understand authorization, scheduling, and cleanup through app-owned notification services."),
                preset: AppText.string("The Basic preset schedules one namespaced immediate notification and observes only safe history summaries."),
                expected: AppText.string("Lab reset preserves Store data; explicitly labelled app-wide controls are confirmed separately.")
            )
        )
    ]
}
