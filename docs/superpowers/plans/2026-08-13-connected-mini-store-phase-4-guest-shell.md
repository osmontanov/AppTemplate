# Connected Mini Store Phase 4: Guest Store and Adaptive Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the active examples with exactly Store and Services, then ship an offline-testable guest catalog, product, reviews, related products, cart, checkout, public Profile, deep links, and scene restoration.

**Architecture:** Each scene owns typed Store/Services histories and item-driven presentations. Compact width uses one `NavigationStack`; regular iPad/macOS uses a custom `HStack` master/detail container under the existing platform shell, never a nested `NavigationSplitView`. `ProductRepository` is the semantic adapter over phase-1 `IRemoteService`; feature capsules consume app-owned repositories through `StoreDependencies`.

**Tech Stack:** Swift 6, SwiftUI, Observation, Foundation, Swift Testing, XCTest/XCUITest, iOS/iPadOS/macOS 26.0, Xcode 26.6

**Normative design:** `docs/superpowers/specs/2026-08-13-connected-mini-store-design.md` at commit `e372913a20bcebd09675fe3f7cf965d2cd40a11d`.

## Global Constraints

- Complete phases 1–3 and consume their exact `AppClock`, `IImageLoader`, `IRemoteService`, `ICartRepository`, `IStorePreferencesRepository`, `SessionController`, and `SessionPresentation`; do not create alternate clock, image, sort, query-mode, or session types.
- Follow RED → intended RED → minimal GREEN → focused regression → commit. Every task compiles all platforms.
- Main contains exactly `.store` and `.services`; macOS Settings remains a native scene, not a third main section.
- Feature code contains no `NavigationSplitView`. Regular content uses the custom Task-1 `HStack`; keep the outer macOS sidebar split view.
- Schema 5 manually encodes route tags and stores section, typed paths, and transition checkpoint. It never stores compiler names, `NavigationPath.CodableRepresentation`, session revision, sheets, checkout, Authentication, or pending actions.
- Store tags are `product`, `reviews`, `favorites`, `cart`, `profile`. Services tags are `app-state`, `app-info`, `user-defaults`, `keychain`, `local-database`, `remote-api`, `local-notifications`.
- Search/category are mutually exclusive. Related results exclude the current ID, deduplicate by ID, sort by ID, then limit.
- Tests/previews use fail-closed scenarios, `AppClock`, and `IImageLoader`; no `AsyncImage`, `URLSession.shared`, live DummyJSON, live Keychain, or disk database.
- Profile, Preferences, About, Cart, and fictional Checkout are public. Favorites and Account enforcement land in phase 5.
- Keep legacy sources until phase 8 but remove them from active routing/composition here.
- Do not modify `AppTemplate.xcodeproj/project.pbxproj`, `AppTemplate/Resources/Localizable.xcstrings`, or `graphify-out/`. Stage only listed paths.

---

### Task 1: Typed Schema 5 and Two-section Adaptive Shell

**Create**

- `AppTemplate/Features/Store/Navigation/StoreRoute.swift`
- `AppTemplate/Features/Store/Navigation/StorePresentation.swift`
- `AppTemplate/Features/Store/Routing/StoreRouter.swift`
- `AppTemplate/Features/Store/Screens/Profile/Model/ProfileSection.swift`
- `AppTemplate/Features/Services/Navigation/ServicesRoute.swift`
- `AppTemplate/Features/Services/Routing/ServicesRouter.swift`
- `AppTemplate/Features/Store/Flow/StoreFlowView.swift`
- `AppTemplate/Features/Services/Flow/ServicesFlowView.swift`
- `AppTemplate/Utilities/UIComponents/AdaptiveFlowLayoutPolicy.swift`
- `AppTemplate/Utilities/UIComponents/AdaptiveFlowNavigationContainer.swift`

**Modify**

- `AppTemplate/App/Navigation/Routing/AppSection.swift`
- `AppTemplate/App/Navigation/Routing/NavigationIntent.swift`
- `AppTemplate/App/Navigation/DeepLinks/DeepLinkParser.swift`
- `AppTemplate/App/Navigation/Containers/AppSectionPresentation.swift`
- `AppTemplate/App/Navigation/Snapshots/NavigationSnapshot.swift`
- `AppTemplate/App/Navigation/Routing/AppRouter.swift`
- `AppTemplate/App/Navigation/Lifecycle/AppSceneNavigationLifecycle.swift`
- `AppTemplate/App/Navigation/Containers/AppSceneView.swift`
- `AppTemplate/App/Navigation/Containers/AppSectionContentView.swift`
- `AppTemplate/App/Navigation/Containers/Platforms/iOS/AdaptiveTabAppShellView.swift`
- `AppTemplate/App/Navigation/Containers/Platforms/iOS/TabAccessibilityIdentifierInstaller.swift`
- `AppTemplate/App/Navigation/Containers/Platforms/macOS/MacSidebarAppShellView.swift`
- `AppTemplate/App/Navigation/Containers/AppRootView.swift`
- `AppTemplate/App/Entry/AppTemplateApp.swift`
- `AppTemplate/App/Entry/ContentView.swift`
- `AppTemplate/App/PreviewSupport/PreviewFixtures.swift`
- `AppTemplate/App/PreviewSupport/PreviewFixtures.swift`

**Test**

- `AppTemplateTests/App/Navigation/Containers/AppSectionPresentationTests.swift`
- `AppTemplateTests/App/Navigation/Containers/TabAccessibilityIdentifierInstallerTests.swift`
- `AppTemplateTests/App/Navigation/Containers/AdaptiveFlowLayoutPolicyTests.swift`
- `AppTemplateTests/App/Navigation/Snapshots/NavigationSnapshotTests.swift`
- `AppTemplateTests/App/Navigation/Routing/AppRouterTests.swift`
- `AppTemplateTests/App/Navigation/DeepLinks/DeepLinkParserTests.swift`
- `AppTemplateTests/App/Navigation/Lifecycle/AppSceneNavigationLifecycleTests.swift`
- `AppTemplateTests/App/Navigation/Notifications/LocalNotificationNavigationCoordinatorTests.swift`
- `AppTemplateTests/Project/ProjectConfigurationTests.swift`

**Consumes**

```swift
nonisolated protocol NavigationRoute: Codable, Hashable, Sendable {}
nonisolated struct SessionPresentation: Equatable, Sendable {
    let state: SessionState
    let revision: UInt64
}
```

**Produces**

```swift
nonisolated enum AppSection: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case store, services
    var id: Self { self }
}
nonisolated enum StoreRoute: NavigationRoute {
    case product(Int), reviews(Int), favorites, cart, profile
}
nonisolated enum ServicesRoute: NavigationRoute {
    case appState, appInfo, userDefaults, keychain, localDatabase, remoteAPI, localNotifications
}
nonisolated enum ProfileSection: Equatable, Sendable { case overview, preferences, about, account }
nonisolated enum StorePresentation: Identifiable, Hashable, Sendable {
    case filters, authentication, checkout, reminder(Int)
    var id: String { get }
}
nonisolated struct NavigationSnapshot: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 5
    let schemaVersion: Int
    let lastAppliedTransitionID: UUID?
    var selectedSection: AppSection
    var storePath: [StoreRoute]
    var servicesPath: [ServicesRoute]
}
@MainActor @Observable final class StoreRouter {
    var path: [StoreRoute]
    var presentation: StorePresentation?
    init(path: [StoreRoute] = [])
    func push(_ route: StoreRoute)
    func replace(with route: StoreRoute)
    func reset()
}
@MainActor @Observable final class ServicesRouter {
    var path: [ServicesRoute]
    init(path: [ServicesRoute] = [])
    func open(_ route: ServicesRoute)
    func reset()
}
nonisolated enum AdaptiveFlowLayout: Equatable, Sendable { case compactStack, regularColumns }
nonisolated enum AdaptiveFlowLayoutPolicy {
    static func resolve(horizontalSizeClass: UserInterfaceSizeClass?, isMacOS: Bool) -> AdaptiveFlowLayout
}
```

Legacy schema-2/3/4 DTOs decode old section names as private strings and discard obsolete paths; schema 4 preserves only `lastAppliedTransitionID`. Schema-5 decoding rejects unknown route keys, rejects non-positive product IDs, and resets only the invalid route section. Future schemas suppress writes. Presentation freezes titles Store/Services, symbols `storefront`/`wrench.and.screwdriver`, presentation IDs `app.section.store`/`app.section.services`, and accessibility IDs `tab.store`/`tab.services`. This task also updates every active compile-time caller in the same commit: `NavigationIntent` temporarily carries only Store/Services root selection, `DeepLinkParser` accepts only those two roots until Task 3 adds strict item routes, `AppSceneNavigationLifecycle` and notification navigation tests use the new roots, and `ProjectConfigurationTests` constructs the replacement shell while any still-retained legacy feature is tested with its own standalone legacy router rather than removed `AppRouter` properties.

- [ ] **RED:** Freeze tags, migration, partial recovery, sections, and layout.

```swift
@Test func wireTagsAndUnknownKeysAreStrict() throws {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
    #expect(String(decoding: try encoder.encode(StoreRoute.product(42)), as: UTF8.self) == #"{"productID":42,"tag":"product"}"#)
    #expect(String(decoding: try encoder.encode(ServicesRoute.localNotifications), as: UTF8.self) == #"{"tag":"local-notifications"}"#)
    #expect(throws: DecodingError.self) { try JSONDecoder().decode(StoreRoute.self, from: Data(#"{"tag":"cart","productID":1}"#.utf8)) }
    #expect(AppSection.allCases == [.store, .services])
    #expect((AppSection.store.systemImage, AppSection.store.presentationIdentifier, AppSection.store.accessibilityIdentifier) == ("storefront", "app.section.store", "tab.store"))
    #expect((AppSection.services.systemImage, AppSection.services.presentationIdentifier, AppSection.services.accessibilityIdentifier) == ("wrench.and.screwdriver", "app.section.services", "tab.services"))
    #expect(AdaptiveFlowLayoutPolicy.resolve(horizontalSizeClass: .regular, isMacOS: false) == .regularColumns)
}
```

- [ ] **RED command:** run exactly; expect nonzero because schema-5 routes/layout do not exist.

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -only-testing:AppTemplateTests/AppSectionPresentationTests -only-testing:AppTemplateTests/TabAccessibilityIdentifierInstallerTests -only-testing:AppTemplateTests/AdaptiveFlowLayoutPolicyTests -only-testing:AppTemplateTests/NavigationSnapshotTests -only-testing:AppTemplateTests/AppRouterTests -only-testing:AppTemplateTests/DeepLinkParserTests -only-testing:AppTemplateTests/AppSceneNavigationLifecycleTests -only-testing:AppTemplateTests/LocalNotificationNavigationCoordinatorTests -only-testing:AppTemplateTests/ProjectConfigurationTests SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
```

- [ ] **GREEN:** implement manual codecs with a navigation-local `DynamicCodingKey` whose `init?(stringValue:)` accepts every string. First decode a dynamic keyed container and reject any `allKeys` outside the allowed string set; only then decode the typed container. Tests add an extra key to StoreRoute, ServicesRoute, and each schema-5 snapshot route section. Use the custom regular branch:

```swift
switch layout {
case .compactStack:
    NavigationStack(path: $path) { master().navigationDestination(for: Route.self, destination: destination) }
case .regularColumns:
    HStack(spacing: 0) {
        NavigationStack { master() }.frame(minWidth: 300, idealWidth: 360, maxWidth: 440)
        Divider()
        NavigationStack(path: $path) { placeholder().navigationDestination(for: Route.self, destination: destination) }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

Set the macOS window content minimum to `820x620`; make compact navigation controls reachable through an overflow menu. Placeholder roots keep this commit compiling.

- [ ] **PASS:** run the RED command plus iPhone/iPad builds; expect exit 0.

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -only-testing:AppTemplateTests/AppSectionPresentationTests -only-testing:AppTemplateTests/TabAccessibilityIdentifierInstallerTests -only-testing:AppTemplateTests/AdaptiveFlowLayoutPolicyTests -only-testing:AppTemplateTests/NavigationSnapshotTests -only-testing:AppTemplateTests/AppRouterTests -only-testing:AppTemplateTests/DeepLinkParserTests -only-testing:AppTemplateTests/AppSceneNavigationLifecycleTests -only-testing:AppTemplateTests/LocalNotificationNavigationCoordinatorTests -only-testing:AppTemplateTests/ProjectConfigurationTests SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
xcodebuild build -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
xcodebuild build -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
xcodebuild build -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.5' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
git add AppTemplate/Features/Store/Navigation AppTemplate/Features/Store/Routing AppTemplate/Features/Store/Screens/Profile/Model/ProfileSection.swift AppTemplate/Features/Store/Flow AppTemplate/Features/Services/Navigation AppTemplate/Features/Services/Routing AppTemplate/Features/Services/Flow AppTemplate/Utilities/UIComponents/AdaptiveFlowLayoutPolicy.swift AppTemplate/Utilities/UIComponents/AdaptiveFlowNavigationContainer.swift AppTemplate/App/Navigation AppTemplate/App/Entry/AppTemplateApp.swift AppTemplate/App/PreviewSupport/PreviewFixtures.swift AppTemplateTests/App/Navigation AppTemplateTests/Project/ProjectConfigurationTests.swift
git commit -m "feat: add typed store services shell"
```

---

### Task 2: Semantic Product Adapter, Guest Capsules, and Fictional Checkout

**Create**

- `AppTemplate/App/Models/Domain/Product.swift`
- `AppTemplate/App/Models/Domain/ProductCategory.swift`
- `AppTemplate/App/Models/Domain/ProductQuery.swift`
- `AppTemplate/App/Repositories/Products/IProductRepository.swift`
- `AppTemplate/App/Repositories/Products/ProductRepository.swift`
- `AppTemplate/Features/Store/Dependencies/StoreDependencies.swift`
- `AppTemplate/Features/Store/Screens/Catalog/Model/CatalogModel.swift`
- `AppTemplate/Features/Store/Screens/Catalog/State/CatalogState.swift`
- `AppTemplate/Features/Store/Screens/Catalog/ViewModel/CatalogViewModel.swift`
- `AppTemplate/Features/Store/Screens/Catalog/View/CatalogView.swift`
- `AppTemplate/Features/Store/Screens/ProductDetail/Model/ProductDetailModel.swift`
- `AppTemplate/Features/Store/Screens/ProductDetail/State/ProductDetailState.swift`
- `AppTemplate/Features/Store/Screens/ProductDetail/ViewModel/ProductDetailViewModel.swift`
- `AppTemplate/Features/Store/Screens/ProductDetail/View/ProductDetailView.swift`
- `AppTemplate/Features/Store/Screens/Reviews/ViewModel/ReviewsViewModel.swift`
- `AppTemplate/Features/Store/Screens/Reviews/View/ReviewsView.swift`
- `AppTemplate/Features/Store/Screens/Cart/ViewModel/CartViewModel.swift`
- `AppTemplate/Features/Store/Screens/Cart/View/CartView.swift`
- `AppTemplate/Features/Store/Screens/Profile/Model/ProfileModel.swift`
- `AppTemplate/Features/Store/Screens/Profile/State/ProfileState.swift`
- `AppTemplate/Features/Store/Screens/Profile/ViewModel/ProfileViewModel.swift`
- `AppTemplate/Features/Store/Screens/Profile/View/ProfileView.swift`
- `AppTemplate/Features/Store/Screens/Preferences/View/StorePreferencesForm.swift`
- `AppTemplate/Features/Store/Settings/StoreSettingsSceneView.swift`
- `AppTemplate/Features/Store/Checkout/Model/CheckoutModel.swift`
- `AppTemplate/Features/Store/Checkout/State/CheckoutState.swift`
- `AppTemplate/Features/Store/Checkout/ViewModel/CheckoutViewModel.swift`
- `AppTemplate/Features/Store/Checkout/Flow/CheckoutFlowView.swift`

**Modify**

- `AppTemplate/Features/Store/Flow/StoreFlowView.swift`
- `AppTemplate/App/AppDependencies/AppDependencies.swift`
- `AppTemplate/App/Navigation/Containers/AppSceneView.swift`
- `AppTemplate/App/Navigation/Containers/AppRootView.swift`
- `AppTemplate/App/Navigation/Containers/AppShellView.swift`
- `AppTemplate/App/Navigation/Containers/AppSectionContentView.swift`
- `AppTemplate/App/Navigation/Containers/Platforms/iOS/AdaptiveTabAppShellView.swift`
- `AppTemplate/App/Navigation/Containers/Platforms/macOS/MacSidebarAppShellView.swift`
- `AppTemplate/App/Entry/AppTemplateApp.swift`

**Test**

- `AppTemplateTests/App/Repositories/Products/ProductRepositoryTests.swift`
- `AppTemplateTests/Features/Store/Screens/Catalog/CatalogViewModelTests.swift`
- `AppTemplateTests/Features/Store/Screens/ProductDetail/ProductDetailViewModelTests.swift`
- `AppTemplateTests/Features/Store/Screens/Cart/CartViewModelTests.swift`
- `AppTemplateTests/Features/Store/Screens/Profile/ProfileViewModelTests.swift`
- `AppTemplateTests/Features/Store/Checkout/CheckoutViewModelTests.swift`
- `AppTemplateTests/App/Composition/AppDependenciesTests.swift`
- `AppTemplateTests/Project/ProjectConfigurationTests.swift`
- `AppTemplateTests/TestSupport/Products/ProductFixtures.swift`
- `AppTemplateTests/TestSupport/Products/ControlledProductRepository.swift`

**Consumes**

```swift
nonisolated struct AppClock: Sendable { let now: @Sendable () -> Date; let monotonicNow: @Sendable () -> ContinuousClock.Instant; let sleep: @Sendable (Duration) async throws -> Void }
nonisolated protocol IImageLoader: Sendable { func load(_ url: URL, policy: ImageLoadPolicy) async throws -> LoadedImage }
nonisolated protocol IRemoteService: Sendable { func products(_ request: ProductPageRequest) async throws -> ProductPageDTO; func categories() async throws -> [ProductCategoryDTO]; func product(id: Int) async throws -> ProductDTO }
nonisolated struct ProductPageRequest: Equatable, Sendable { let mode: ProductQueryMode; let sort: ProductSort?; let limit: Int; let skip: Int }
nonisolated protocol ICartRepository: Sendable { func cart() async throws -> CartAggregate; func add(_ product: ProductSnapshot, quantity: Int) async throws -> CartAggregate; func setQuantity(productID: Int, quantity: Int) async throws -> CartAggregate; func remove(productID: Int) async throws -> CartAggregate; func checkout(expectedRevision: Int64) async throws }
nonisolated protocol IStorePreferencesRepository: Sendable { func current() async -> StorePreferences; func updates() async -> AsyncStream<StorePreferences>; func setLayout(_ layout: StoreCatalogLayout) async throws; func setSort(_ sort: StoreCatalogSort) async throws; func setPreferredRemotePageSize(_ size: Int) async throws }
```

Phase 1 owns `ProductQueryMode` and `ProductSort`; phase 2 owns `StoreCatalogLayout`, `StoreCatalogSort`, `StorePreferences`, `CartAggregate`, and `ProductSnapshot`.

**Produces**

```swift
nonisolated struct ProductReview: Identifiable, Hashable, Sendable { let id: Int; let rating: Int; let comment: String; let date: Date; let reviewerName: String } // owned by Product.swift
nonisolated struct ProductCategory: Identifiable, Hashable, Sendable { let slug: String; let name: String; var id: String { slug } }
nonisolated struct Product: Identifiable, Hashable, Sendable { typealias ID = Int; let id: ID; let title: String; let description: String; let category: String; let price: Decimal; let rating: Double; let stock: Int; let thumbnailURL: URL?; let imageURLs: [URL]; let reviews: [ProductReview]; var snapshot: ProductSnapshot { get } }
nonisolated struct ProductQuery: Equatable, Sendable { let mode: ProductQueryMode; let sort: ProductSort?; let limit: Int; let skip: Int }
nonisolated struct ProductPage: Equatable, Sendable { let products: [Product]; let total: Int; let skip: Int; let limit: Int }
nonisolated protocol IProductRepository: Sendable { func categories() async throws -> [ProductCategory]; func page(_ query: ProductQuery) async throws -> ProductPage; func product(id: Product.ID) async throws -> Product; func related(to product: Product, limit: Int) async throws -> [Product] }
nonisolated struct ProductMapper: Sendable { func categories(_ values: [ProductCategoryDTO]) throws -> [ProductCategory]; func page(_ value: ProductPageDTO) throws -> ProductPage; func product(_ value: ProductDTO) throws -> Product }
actor ProductRepository: IProductRepository { init(remote: any IRemoteService, mapper: ProductMapper = ProductMapper()); func categories() async throws -> [ProductCategory]; func page(_ query: ProductQuery) async throws -> ProductPage; func product(id: Product.ID) async throws -> Product; func related(to product: Product, limit: Int) async throws -> [Product] }
@MainActor struct StoreDependencies: Sendable { let products: any IProductRepository; let cart: any ICartRepository; let preferences: any IStorePreferencesRepository; let appInfo: any IAppInfoService }
nonisolated struct StoreUISupport: Sendable { let images: any IImageLoader; let clock: AppClock }
nonisolated enum CheckoutField: Hashable, Sendable { case recipient, address, note }
nonisolated struct CheckoutModel: Equatable, Sendable { static let fictionalPrefill: CheckoutModel; var recipient: String; var address: String; var note: String; func firstInvalidField() -> CheckoutField? }
nonisolated enum CheckoutStep: Equatable, Sendable { case delivery, review, success }
nonisolated enum CheckoutState: Equatable, Sendable { case editing(step: CheckoutStep, model: CheckoutModel); case submitting(CheckoutModel); case failed(CheckoutModel); case success }
@MainActor @Observable final class CheckoutViewModel { init(cart: CartAggregate, repository: any ICartRepository, onDone: @escaping () -> Void, onRevisionConflict: @escaping () -> Void); private(set) var state: CheckoutState; func continueToReview(); func editDelivery(); func placeDemoOrder() async; func retryPlaceDemoOrder() async; func done() }
@MainActor struct CheckoutFlowView: View { init(cart: CartAggregate, repository: any ICartRepository, onDone: @escaping () -> Void, onRevisionConflict: @escaping () -> Void) }
```

Phase 4 freezes `@MainActor func AppDependencies.makeStoreDependencies() -> StoreDependencies` plus one app-owned `storeUISupport: StoreUISupport`. `Product.snapshot` is the sole conversion into the phase-2 persistence value and copies exactly `id`, `title`, `price`, and `thumbnailURL`; Favorites and Cart never remap DTOs themselves. `AppTemplateApp` calls the factory once and passes both slices through the exact scene/root/shell/platform/content chain listed in Modify. Phase 5 evolves only this factory to accept its app-owned session controller; Views never receive all of `AppDependencies`.

- [ ] **RED:** prove deterministic related results, exact `Product.snapshot` mapping (`id/title/price/thumbnailURL`), stale-load suppression, pagination reset, and checkout revision safety.

```swift
@Test func relatedIsDeduplicatedSortedAndLimited() async throws {
    let repository = ProductRepository(remote: RemoteServiceSpy(pageIDs: [4, 2, 3, 4, 1]))
    #expect(try await repository.related(to: .fixture(id: 2, category: "phones"), limit: 3).map(\.id) == [1, 3, 4])
}
@MainActor @Test func checkoutConflictDismissesToCartWithoutFalseSuccess() async {
    let repository = CartRepositorySpy(
        checkoutError: .revisionConflict(expected: 9, actual: 10)
    )
    var conflictCount = 0
    let viewModel = CheckoutViewModel(cart: .fixture(revision: 9), repository: repository, onDone: {}, onRevisionConflict: { conflictCount += 1 })
    viewModel.continueToReview(); await viewModel.placeDemoOrder()
    #expect(repository.expectedRevisions == [9]); #expect(conflictCount == 1)
}
```

Also cover query validation, category trimming/nonempty mapping, duplicate slug first-wins then slug sort, and the explicit endpoint capability matrix: sorting is enabled only for `.all`; Catalog disables its sort control for `.search`/`.category`, emits `sort: nil`, and the repository rejects a nonnil sort for either unsupported mode before transport. Cover the 100-character search cap, 300ms cancellable debounce, latest generation wins, page-ID dedupe, cancellation silence, cart failures, empty-cart checkout disabled, UI page choices `10/20/30/50`, fictional delivery prefill, all fields capped at 100 Unicode scalars, deterministic first-invalid focus, Delivery → Review → Success, edit back to Delivery, failure retry with the launch revision, no remote/payment calls, and Success retained until Done.

- [ ] **RED command:** expect nonzero because repositories/capsules/checkout are absent.

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -only-testing:AppTemplateTests/ProductRepositoryTests -only-testing:AppTemplateTests/CatalogViewModelTests -only-testing:AppTemplateTests/ProductDetailViewModelTests -only-testing:AppTemplateTests/CartViewModelTests -only-testing:AppTemplateTests/ProfileViewModelTests -only-testing:AppTemplateTests/CheckoutViewModelTests -only-testing:AppTemplateTests/AppDependenciesTests SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
```

- [ ] **GREEN:** map `ProductQuery` to the phase-1 request and implement related deterministically.

```swift
func page(_ query: ProductQuery) async throws -> ProductPage {
    try validate(query)
    let dto = try await remote.products(.init(mode: query.mode, sort: query.sort, limit: query.limit, skip: query.skip))
    return try mapper.page(dto)
}
func related(to product: Product, limit: Int) async throws -> [Product] {
    guard limit > 0 else { return [] }
    let values = try await page(.init(mode: .category(product.category), sort: nil, limit: min(100, limit + 20), skip: 0)).products
    return Array(Dictionary(grouping: values.filter { $0.id != product.id }, by: \.id).compactMap { $0.value.first }.sorted { $0.id < $1.id }.prefix(limit))
}
```

Validate limit `1...100`, skip `>=0`, trimmed nonempty search/category text, and reject `sort != nil` unless mode is `.all`. `categories()` is the only Catalog category source: map nonempty trimmed slug/name, keep the first duplicate slug, then sort by slug. Freeze preference mapping `featured → nil`, `titleAscending/Descending → matching ProductSort`, `priceAscending/Descending → matching ProductSort`; Catalog applies that mapping only in `.all`, visibly disables sorting and sends `nil` in `.search`/`.category`, while current value, async updates, and page size changes remain shared across scenes through the app repository. Map each review to stable 1-based source index, preserve order, and ignore reviewer email. Checkout snapshots `cart.revision` at init and calls only `checkout(expectedRevision:)`; conflict invokes `onRevisionConflict`, dismisses, and Cart owns the explanation. Other failure retains Review for retry; Success remains until Done. Compose one `IAppInfoService` in `AppDependencies` and share that exact instance with Store Profile/About, native Settings, and the later Services AppInfo lab. Keep image/clock mechanics in `StoreUISupport`; feature ViewModels receive only the support member they actually need. Pass both narrow slices through the full explicit initializer chain, including direct `ContentView`/ProjectConfiguration constructors and fail-closed preview fixtures; no convenience initializer may create a second repository or live service.

- [ ] **PASS:** run the RED command and iOS build; expect exit 0, then commit exact paths.

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -only-testing:AppTemplateTests/ProductRepositoryTests -only-testing:AppTemplateTests/CatalogViewModelTests -only-testing:AppTemplateTests/ProductDetailViewModelTests -only-testing:AppTemplateTests/CartViewModelTests -only-testing:AppTemplateTests/ProfileViewModelTests -only-testing:AppTemplateTests/CheckoutViewModelTests -only-testing:AppTemplateTests/AppDependenciesTests -only-testing:AppTemplateTests/ProjectConfigurationTests SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
xcodebuild build -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
git add AppTemplate/App/Models/Domain/Product.swift AppTemplate/App/Models/Domain/ProductCategory.swift AppTemplate/App/Models/Domain/ProductQuery.swift AppTemplate/App/Repositories/Products AppTemplate/Features/Store/Dependencies AppTemplate/Features/Store/Screens AppTemplate/Features/Store/Settings AppTemplate/Features/Store/Checkout AppTemplate/Features/Store/Flow/StoreFlowView.swift AppTemplate/App/AppDependencies/AppDependencies.swift AppTemplate/App/Navigation/Containers AppTemplate/App/Entry/AppTemplateApp.swift AppTemplate/App/Entry/ContentView.swift AppTemplate/App/PreviewSupport/PreviewFixtures.swift AppTemplateTests/App/Repositories/Products AppTemplateTests/Features/Store AppTemplateTests/TestSupport/Products AppTemplateTests/App/Composition/AppDependenciesTests.swift AppTemplateTests/Project/ProjectConfigurationTests.swift
git commit -m "feat: add deterministic guest store and checkout"
```

---

### Task 3: Strict Links, Scene Actions, and Offline Acceptance

**Create**

- `AppTemplate/App/Navigation/Scene/ISceneNavigationActions.swift`
- `AppTemplate/App/Navigation/Scene/SceneNavigationPresentation.swift`

**Modify**

- `AppTemplate/App/Navigation/Routing/NavigationIntent.swift`
- `AppTemplate/App/Navigation/DeepLinks/DeepLinkParser.swift`
- `AppTemplate/App/Navigation/Routing/AppRouter.swift`
- `AppTemplate/App/Navigation/Lifecycle/AppSceneNavigationLifecycle.swift`
- `AppTemplate/App/Navigation/Containers/AppSceneView.swift`
- `AppTemplate/App/Entry/AppLaunchConfiguration.swift`
- `AppTemplate/App/Entry/UITesting/UITestScenarioSeeds.swift`
- `AppTemplate/App/AppDependencies/AppDependencies.swift`

**Test**

- `AppTemplateTests/App/Navigation/DeepLinks/DeepLinkParserTests.swift`
- `AppTemplateTests/App/Navigation/Lifecycle/AppSceneNavigationLifecycleTests.swift`
- `AppTemplateTests/App/Navigation/Scene/SceneNavigationActionsTests.swift`
- `AppTemplateTests/App/Entry/AppLaunchConfigurationTests.swift`
- `AppTemplateUITests/Flows/ShellUITests.swift`
- `AppTemplateUITests/TestSupport/AppRobot.swift`
- `AppTemplateUITests/TestSupport/StoreRobot.swift`

**Consumes**

```swift
nonisolated struct UITestScenario: Equatable, Sendable { nonisolated enum Name: String, CaseIterable, Codable, Sendable { case guestStore = "guest-store", protectedFavorite = "protected-favorite", productReminder = "product-reminder", servicesBasic = "services-basic", accessibilitySmoke = "accessibility-smoke" }; let id: Name; let appState: AppState; let sessionSeed: UITestSessionSeed; let localDatabaseSeed: UITestLocalDatabaseSeed; let preferencesSeed: UITestPreferencesSeed; let notificationSeed: UITestNotificationSeed; let imageSeed: UITestImageSeed; let networkPolicy: UITestNetworkPolicy; let remoteSteps: [ScriptedNetworkStep]; static func named(_ id: String) throws -> UITestScenario }
nonisolated enum UITestNetworkPolicy: Equatable, Sendable { case failClosed }
nonisolated struct SessionPresentation: Equatable, Sendable { let state: SessionState; let revision: UInt64 }
nonisolated enum NavigationRestorationResult: Equatable, Sendable { case noState, restored, migrated(from: Int), recovered(Set<AppSection>), reset(NavigationRestorationFailure), preservedFutureSchema(Int) }
```

**Produces**

```swift
nonisolated enum NavigationIntent: Equatable, Sendable { case openStoreRoot, openProduct(Product.ID), openFavorites, openProfile, openServicesRoot, openService(ServicesRoute) }
nonisolated enum DeepLinkError: Equatable, Sendable { case invalidScheme, credentialsNotAllowed, portNotAllowed, queryNotAllowed, fragmentNotAllowed, unsupportedHost, invalidSegments, invalidProductID }
nonisolated struct DeepLinkParser: Sendable { init(scheme: String = "apptemplate"); func parse(_ url: URL) -> Result<NavigationIntent, DeepLinkError> }
nonisolated enum DeepLinkRecoveryAction: Equatable, Sendable { case openStore, openServices }
nonisolated struct DeepLinkFailurePresentation: Equatable, Sendable { let reason: DeepLinkError }
nonisolated struct SceneNavigationPresentation: Equatable, Sendable { let selectedSection: AppSection; let storePath: [StoreRoute]; let servicesPath: [ServicesRoute]; let restorationResult: NavigationRestorationResult; let checkpoint: UUID?; let hasDeferredLink: Bool; let hasPendingProtectedAction: Bool; let deepLinkFailure: DeepLinkFailurePresentation? }
@MainActor protocol ISceneNavigationActions: AnyObject { func presentation() -> SceneNavigationPresentation; func resetNavigationInCurrentScene(); func handleSampleIntent(_ intent: NavigationIntent); func recoverRejectedLink(_ action: DeepLinkRecoveryAction) }
@MainActor final class AppSceneNavigationLifecycle: ISceneNavigationActions { func restore(from data: Data?, applying transition: AppFlowTransition) -> NavigationSnapshot?; func receive(_ url: URL) -> NavigationSnapshot?; func presentation() -> SceneNavigationPresentation; func resetNavigationInCurrentScene(); func handleSampleIntent(_ intent: NavigationIntent); func recoverRejectedLink(_ action: DeepLinkRecoveryAction) }
```

Accepted URLs are exactly `apptemplate://store`, `/product/<positive base-10 Int>`, `/favorites`, `/profile`; `apptemplate://services`; and `/app-state`, `/app-info`, `/user-defaults`, `/keychain`, `/local-database`, `/remote-api`, `/local-notifications`. Only the latest valid link is deferred while restoration is incomplete or root is not Main. Reject user/password, port, query, fragment, legacy/unknown host, extra or empty/trailing segments, overflowing/nonpositive IDs. Rejection preserves both paths and the deferred slot, but sets a typed content-free failure. `AppSceneView` renders explicit Open Store/Open Services recovery buttons; recovery clears the failure and replaces only the selected section root. `.openFavorites` parses but phase 5 protects it.

In phase 4, `presentation().hasPendingProtectedAction` is always `false`; phase 5 changes only that computed source to the scene's `StoreRouter` state.

- [ ] **RED:** test strict parsing, invalid zero mutation, one deferred slot, and scene isolation.

```swift
@MainActor @Test func resetTouchesOnlyCurrentScene() {
    let first = AppSceneNavigationLifecycle.fixture(storePath: [.product(1)])
    let second = AppSceneNavigationLifecycle.fixture(storePath: [.product(2)])
    first.resetNavigationInCurrentScene()
    #expect(first.presentation().storePath.isEmpty)
    #expect(second.presentation().storePath == [.product(2)])
}
@MainActor @Test func invalidLinkDoesNotEraseLatestValidDeferredIntent() throws {
    let scene = AppSceneNavigationLifecycle.unrestoredFixture()
    _ = scene.receive(try #require(URL(string: "apptemplate://store/product/7")))
    _ = scene.receive(try #require(URL(string: "apptemplate://legacy/private")))
    #expect(scene.presentation().hasDeferredLink)
    #expect(scene.presentation().deepLinkFailure == .init(reason: .unsupportedHost))
}
@MainActor @Test func immediateNewLinkSupersedesAnOlderDeferredLink() throws {
    let scene = AppSceneNavigationLifecycle.unrestoredFixture()
    _ = scene.receive(try #require(URL(string: "apptemplate://store/product/7")))
    _ = scene.restoreMainThenReceive(try #require(URL(string: "apptemplate://store/product/9")))
    scene.applyLaterRootTransitionForTest()
    #expect(scene.presentation().storePath == [.product(9)])
    #expect(!scene.presentation().hasDeferredLink)
}
```

Add table tests for every accepted URL and every rejection class, including `?x=1`, `#fragment`, `user@`, `:443`, `//`, trailing slash, extra segment, `0`, `-1`, and integer overflow. Recovery tests prove Open Store/Open Services are explicit and scene-local.

- [ ] **RED command:** expect nonzero because strict links and scene-actions do not exist.

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -only-testing:AppTemplateTests/DeepLinkParserTests -only-testing:AppTemplateTests/AppSceneNavigationLifecycleTests -only-testing:AppTemplateTests/SceneNavigationActionsTests -only-testing:AppTemplateTests/AppLaunchConfigurationTests SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
```

- [ ] **GREEN:** parse exact scheme/host/segments and keep `private var deferredIntent: NavigationIntent?`; assign it only after successful parsing. On failure set only `deepLinkFailure = .init(reason: error)`. A later valid parse clears the stale failure whether it is applied now or becomes the latest deferred intent. Before applying any valid intent immediately, clear `deferredIntent`; when the root later changes, atomically take-and-clear a deferred value before applying it. This makes the newest valid link win and prevents a stale pre-restoration link from replaying over a newer immediate link. `recoverRejectedLink(.openStore/.openServices)` clears the failure and any obsolete deferred value before calling the matching root intent. `handleSampleIntent` uses the same router path as real links. Extend the phase-1 local-database seed with phase-2 favorite/cart values without duplicating the scenario type. The isolated scenario scripts two catalog pages, details/reviews, empty cart, Profile metadata, preferences, Guest, in-memory persistence, and images; every unplanned request fails.

```swift
func receive(_ url: URL) -> NavigationSnapshot? {
    let intent: NavigationIntent
    switch parser.parse(url) {
    case let .success(value): intent = value
    case let .failure(error): deepLinkFailure = .init(reason: error); return nil
    }
    guard hasRestored, router.currentRoot == .main else { deferredIntent = intent; return nil }
    deferredIntent = nil
    handleSampleIntent(intent)
    return snapshotForPersistence
}
```

- [ ] **PASS:** run unit and representative UI commands; expect exit 0. UI opens catalog → product → reviews → related product → cart → checkout conflict/success → public Profile → Services → preserved Store, then waits for `ui-test.script-status.exhausted`; pending/failed/timeout fails the journey.

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -only-testing:AppTemplateTests/DeepLinkParserTests -only-testing:AppTemplateTests/AppSceneNavigationLifecycleTests -only-testing:AppTemplateTests/SceneNavigationActionsTests -only-testing:AppTemplateTests/AppLaunchConfigurationTests SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:AppTemplateUITests/ShellUITests/testGuestStoreJourney SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
git add AppTemplate/App/Navigation/Scene AppTemplate/App/Navigation/Routing/NavigationIntent.swift AppTemplate/App/Navigation/DeepLinks/DeepLinkParser.swift AppTemplate/App/Navigation/Routing/AppRouter.swift AppTemplate/App/Navigation/Lifecycle/AppSceneNavigationLifecycle.swift AppTemplate/App/Navigation/Containers/AppSceneView.swift AppTemplate/App/Entry/AppLaunchConfiguration.swift AppTemplate/App/Entry/UITesting/UITestScenarioSeeds.swift AppTemplate/App/AppDependencies/AppDependencies.swift AppTemplateTests/App/Navigation AppTemplateTests/App/Entry/AppLaunchConfigurationTests.swift AppTemplateUITests/Flows/ShellUITests.swift AppTemplateUITests/TestSupport/AppRobot.swift AppTemplateUITests/TestSupport/StoreRobot.swift
git commit -m "feat: add scene-local store navigation actions"
```

## Phase 4 Exit Gate

Run roadmap boundary commands, then `! rg -n 'NavigationSplitView' AppTemplate/Features/Store AppTemplate/Features/Services AppTemplate/Utilities/UIComponents/AdaptiveFlowNavigationContainer.swift` and `! rg -n 'AsyncImage|URLSession\.shared' AppTemplate/Features/Store`. Both guards must exit 0. Phase 5 consumes typed paths, `StorePresentation`, public Profile models, scene actions, strict links, and semantic repositories.
