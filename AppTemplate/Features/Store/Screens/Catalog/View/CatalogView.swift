import SwiftUI

struct CatalogView: View {
    @Bindable var router: StoreRouter
    let images: ImageService
    @State private var viewModel: CatalogViewModel
    @FocusState private var searchIsFocused: Bool
    @AccessibilityFocusState private var resultIsFocused: Bool
    let searchRequestID: Int

    init(
        router: StoreRouter,
        viewModel: CatalogViewModel,
        images: ImageService,
        searchRequestID: Int = 0
    ) {
        self.router = router
        self.images = images
        self.searchRequestID = searchRequestID
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Group {
            if viewModel.model.products.isEmpty, viewModel.state == .loading {
                ProgressView(AppText.resource("Loading products"))
                    .accessibilityIdentifier(AppAccessibilityIdentifier.result(.loading))
            } else if viewModel.model.products.isEmpty {
                ContentUnavailableView(
                    viewModel.errorMessage ?? AppText.string("No products found"),
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
        .navigationTitle(AppText.resource("Catalog"))
        .searchable(text: $viewModel.searchText, prompt: AppText.resource("Search products"))
        .searchFocused($searchIsFocused)
        .onChange(of: searchRequestID) { _, _ in searchIsFocused = true }
        .task {
            guard await viewModel.loadInitial() else { return }
            guard !Task.isCancelled else { return }
            resultIsFocused = viewModel.model.products.isEmpty
            AccessibilityNotification.Announcement(
                viewModel.model.products.isEmpty
                    ? AppText.string("No products are available")
                    : AppText.string("Products loaded")
            ).post()
            await viewModel.observePreferences()
        }
        .task(id: viewModel.searchText) {
            guard viewModel.isInitialLoadComplete else { return }
            await viewModel.search(viewModel.searchText)
        }
        .onChange(of: viewModel.selectedCategory) { _, value in
            Task {
                guard viewModel.isInitialLoadComplete else { return }
                await viewModel.selectCategory(value.isEmpty ? nil : value)
            }
        }
        .toolbar { toolbarContent }
        .safeAreaInset(edge: .bottom) {
            Text(AppText.resource("Demo prices are shown in USD."))
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
            Button(AppText.resource("Load more")) { Task { await viewModel.loadNextPage() } }
                .frame(minHeight: 44)
                .accessibilityIdentifier("action.store.load-more")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            Picker(AppText.resource("Category"), selection: $viewModel.selectedCategory) {
                Text(AppText.resource("All")).tag("")
                ForEach(viewModel.model.categories) { category in
                    Text(verbatim: category.name).tag(category.slug)
                }
            }
            Picker(AppText.resource("Sort"), selection: Binding(
                get: { viewModel.model.preferences.sort },
                set: { value in Task { await viewModel.setSort(value) } }
            )) {
                ForEach(StoreCatalogSort.allCases, id: \.self) { sort in
                    Text(sort.title).tag(sort)
                }
            }
            .disabled(!viewModel.isSortingEnabled)
            Menu(AppText.resource("Display"), systemImage: "slider.horizontal.3") {
                Picker(AppText.resource("Layout"), selection: Binding(
                    get: { viewModel.model.preferences.layout },
                    set: { value in Task { await viewModel.setLayout(value) } }
                )) {
                    Text(AppText.resource("Grid")).tag(StoreCatalogLayout.grid)
                    Text(AppText.resource("List")).tag(StoreCatalogLayout.list)
                }
                Picker(AppText.resource("Page size"), selection: Binding(
                    get: { viewModel.model.preferences.preferredRemotePageSize },
                    set: { value in Task { await viewModel.setPageSize(value) } }
                )) {
                    ForEach(CatalogViewModel.pageSizeChoices, id: \.self) { Text(AppText.resource("\($0)")).tag($0) }
                }
            }
        }
    }
}

private struct ProductCatalogRow: View {
    let product: Product
    let images: ImageService
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let url = product.thumbnailURL {
                RemoteImage(url: url, images: images)
                    .frame(minHeight: 100, maxHeight: 150)
            }
            Text(verbatim: product.title).font(.headline)
            Text(verbatim: AppFormatting.priceUSD(product.price, locale: locale))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }
}

extension StoreCatalogSort {
    var title: String {
        switch self {
        case .featured: AppText.string("Featured")
        case .titleAscending: AppText.string("Title A–Z")
        case .titleDescending: AppText.string("Title Z–A")
        case .priceAscending: AppText.string("Price low to high")
        case .priceDescending: AppText.string("Price high to low")
        }
    }
}
