import SwiftUI

struct CatalogView: View {
    @Bindable var router: StoreRouter
    let images: any IImageLoader
    @State private var viewModel: CatalogViewModel
    @State private var searchText = ""
    @State private var selectedCategory = ""
    @State private var hasLoadedInitialCatalog = false
    @FocusState private var searchIsFocused: Bool
    @AccessibilityFocusState private var resultIsFocused: Bool
    let searchRequestID: Int

    init(
        router: StoreRouter,
        products: any IProductRepository,
        preferences: any IStorePreferencesRepository,
        images: any IImageLoader,
        clock: AppClock,
        searchRequestID: Int = 0
    ) {
        self.router = router
        self.images = images
        self.searchRequestID = searchRequestID
        _viewModel = State(initialValue: CatalogViewModel(
            products: products,
            preferences: preferences,
            clock: clock
        ))
    }

    var body: some View {
        Group {
            if viewModel.model.products.isEmpty, viewModel.state == .loading {
                ProgressView(StoreServicesText.resource("Loading products"))
                    .accessibilityIdentifier(AppAccessibilityIdentifier.result(.loading))
            } else if viewModel.model.products.isEmpty {
                ContentUnavailableView(
                    viewModel.errorMessage ?? StoreServicesText.string("No products found"),
                    systemImage: "shippingbox"
                )
                .accessibilityIdentifier(
                    AppAccessibilityIdentifier.result(
                        viewModel.errorMessage == nil ? .empty : .actualFailure
                    )
                )
                .accessibilityFocused($resultIsFocused)
            } else if viewModel.model.preferences.layout == .grid {
                grid
            } else {
                list
            }
        }
        .navigationTitle(StoreServicesText.resource("Catalog"))
        .searchable(text: $searchText, prompt: StoreServicesText.resource("Search products"))
        .searchFocused($searchIsFocused)
        .onChange(of: searchRequestID) { _, _ in searchIsFocused = true }
        .task {
            await viewModel.loadInitial()
            guard !Task.isCancelled else { return }
            resultIsFocused = viewModel.model.products.isEmpty
            AccessibilityNotification.Announcement(
                viewModel.model.products.isEmpty
                    ? StoreServicesText.string("No products are available")
                    : StoreServicesText.string("Products loaded")
            ).post()
            hasLoadedInitialCatalog = true
            await viewModel.observePreferences()
        }
        .task(id: searchText) {
            guard hasLoadedInitialCatalog else { return }
            await viewModel.search(searchText)
        }
        .onChange(of: selectedCategory) { _, value in
            Task { await viewModel.selectCategory(value.isEmpty ? nil : value) }
        }
        .toolbar { toolbarContent }
        .safeAreaInset(edge: .bottom) {
            Text(StoreServicesText.resource(.demoUSDAssumption))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(8)
        }
        .accessibilityIdentifier(AppAccessibilityIdentifier.screen(.storeCatalog))
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 16)], spacing: 16) {
                ForEach(viewModel.model.products) { product in
                    Button { router.push(.product(product.id)) } label: {
                        ProductCatalogRow(product: product, images: images)
                    }
                    .buttonStyle(.plain)
                }
                loadMore
            }
            .padding()
        }
    }

    private var list: some View {
        List {
            ForEach(viewModel.model.products) { product in
                Button { router.push(.product(product.id)) } label: {
                    ProductCatalogRow(product: product, images: images)
                }
                .buttonStyle(.plain)
            }
            loadMore
        }
    }

    @ViewBuilder
    private var loadMore: some View {
        if viewModel.canLoadMore {
            Button(StoreServicesText.resource("Load more")) { Task { await viewModel.loadNextPage() } }
                .frame(minHeight: 44)
                .accessibilityIdentifier("action.store.load-more")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            Picker(StoreServicesText.resource("Category"), selection: $selectedCategory) {
                Text(StoreServicesText.resource("All")).tag("")
                ForEach(viewModel.model.categories) { category in
                    Text(verbatim: category.name).tag(category.slug)
                }
            }
            Picker(StoreServicesText.resource("Sort"), selection: Binding(
                get: { viewModel.model.preferences.sort },
                set: { value in Task { await viewModel.setSort(value) } }
            )) {
                ForEach(StoreCatalogSort.allCases, id: \.self) { sort in
                    Text(sort.title).tag(sort)
                }
            }
            .disabled(!viewModel.isSortingEnabled)
            Menu(StoreServicesText.resource("Display"), systemImage: "slider.horizontal.3") {
                Picker(StoreServicesText.resource("Layout"), selection: Binding(
                    get: { viewModel.model.preferences.layout },
                    set: { value in Task { await viewModel.setLayout(value) } }
                )) {
                    Text(StoreServicesText.resource("Grid")).tag(StoreCatalogLayout.grid)
                    Text(StoreServicesText.resource("List")).tag(StoreCatalogLayout.list)
                }
                Picker(StoreServicesText.resource("Page size"), selection: Binding(
                    get: { viewModel.model.preferences.preferredRemotePageSize },
                    set: { value in Task { await viewModel.setPageSize(value) } }
                )) {
                    ForEach(CatalogViewModel.pageSizeChoices, id: \.self) { Text(StoreServicesText.resource("\($0)")).tag($0) }
                }
            }
        }
    }
}

private struct ProductCatalogRow: View {
    let product: Product
    let images: any IImageLoader
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let url = product.thumbnailURL {
                RemoteProductImage(url: url, imageLoader: images)
                    .frame(minHeight: 100, maxHeight: 150)
            }
            Text(verbatim: product.title).font(.headline)
            Text(verbatim: StoreFormatting.priceUSD(product.price, locale: locale))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }
}

extension StoreCatalogSort {
    var title: String {
        switch self {
        case .featured: StoreServicesText.string("Featured")
        case .titleAscending: StoreServicesText.string("Title A–Z")
        case .titleDescending: StoreServicesText.string("Title Z–A")
        case .priceAscending: StoreServicesText.string("Price low to high")
        case .priceDescending: StoreServicesText.string("Price high to low")
        }
    }
}
