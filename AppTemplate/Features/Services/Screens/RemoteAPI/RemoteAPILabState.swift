nonisolated
struct RemoteAPILabState: Equatable, Sendable {
    var productIDs: [Int]
    var categorySlugs: [String]
    var nextSkip: Int
    var isLoading: Bool
    var diagnosticEvents: [NetworkDiagnosticEvent]

    init(
        productIDs: [Int] = [],
        categorySlugs: [String] = [],
        nextSkip: Int = 0,
        isLoading: Bool = false,
        diagnosticEvents: [NetworkDiagnosticEvent] = []
    ) {
        self.productIDs = productIDs
        self.categorySlugs = categorySlugs
        self.nextSkip = nextSkip
        self.isLoading = isLoading
        self.diagnosticEvents = diagnosticEvents
    }
}

nonisolated
enum RemoteLabRetryOperation: Equatable, Sendable {
    case search(String)
    case categories
    case categoryProducts(String)
    case detail(Int)
    case nextPage
    case diagnostic(HTTPDiagnosticRequest)
    case validate
    case refresh
}
