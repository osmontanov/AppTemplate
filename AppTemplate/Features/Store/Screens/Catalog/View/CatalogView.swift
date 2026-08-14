import SwiftUI

struct CatalogView: View {
    @Bindable var router: StoreRouter
    let images: any IImageLoader
    @State private var viewModel: CatalogViewModel
    @State private var searchText = ""
    @State private var selectedCategory = ""
    @State private var hasLoadedInitialCatalog = false

    init(
        router: StoreRouter,
        products: any IProductRepository,
        preferences: any IStorePreferencesRepository,
        images: any IImageLoader,
        clock: AppClock
    ) {
        self.router = router
        self.images = images
        _viewModel = State(initialValue: CatalogViewModel(
            products: products,
            preferences: preferences,
            clock: clock
        ))
    }

    var body: some View {
        Group {
            if viewModel.model.products.isEmpty, viewModel.state == .loading {
                ProgressView("Loading products")
            } else if viewModel.model.products.isEmpty {
                ContentUnavailableView(
                    viewModel.errorMessage ?? "No products found",
                    systemImage: "shippingbox"
                )
            } else if viewModel.model.preferences.layout == .grid {
                grid
            } else {
                list
            }
        }
        .navigationTitle("Catalog")
        .searchable(text: $searchText, prompt: "Search products")
        .task {
            await viewModel.loadInitial()
            guard !Task.isCancelled else { return }
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
        .accessibilityIdentifier("screen.store.catalog")
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
            Button("Load more") { Task { await viewModel.loadNextPage() } }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            Picker("Category", selection: $selectedCategory) {
                Text("All").tag("")
                ForEach(viewModel.model.categories) { category in
                    Text(verbatim: category.name).tag(category.slug)
                }
            }
            Picker("Sort", selection: Binding(
                get: { viewModel.model.preferences.sort },
                set: { value in Task { await viewModel.setSort(value) } }
            )) {
                ForEach(StoreCatalogSort.allCases, id: \.self) { sort in
                    Text(sort.title).tag(sort)
                }
            }
            .disabled(!viewModel.isSortingEnabled)
            Menu("Display", systemImage: "slider.horizontal.3") {
                Picker("Layout", selection: Binding(
                    get: { viewModel.model.preferences.layout },
                    set: { value in Task { await viewModel.setLayout(value) } }
                )) {
                    Text("Grid").tag(StoreCatalogLayout.grid)
                    Text("List").tag(StoreCatalogLayout.list)
                }
                Picker("Page size", selection: Binding(
                    get: { viewModel.model.preferences.preferredRemotePageSize },
                    set: { value in Task { await viewModel.setPageSize(value) } }
                )) {
                    ForEach(CatalogViewModel.pageSizeChoices, id: \.self) { Text("\($0)").tag($0) }
                }
            }
        }
    }
}

private struct ProductCatalogRow: View {
    let product: Product
    let images: any IImageLoader

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let url = product.thumbnailURL {
                RemoteProductImage(url: url, imageLoader: images)
                    .frame(minHeight: 100, maxHeight: 150)
            }
            Text(verbatim: product.title).font(.headline)
            Text(verbatim: "$\(product.price)").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }
}

extension StoreCatalogSort {
    var title: String {
        switch self {
        case .featured: "Featured"
        case .titleAscending: "Title A–Z"
        case .titleDescending: "Title Z–A"
        case .priceAscending: "Price low to high"
        case .priceDescending: "Price high to low"
        }
    }
}
