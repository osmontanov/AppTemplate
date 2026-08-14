nonisolated
struct ServiceLabGuide: Equatable, Sendable {
    let why: String
    let preset: String
    let expected: String
}

nonisolated
enum ServiceLabResult: Equatable, Sendable {
    case idle
    case running
    case success(String)
    case failure(String)

    var isSuccess: Bool {
        if case .success = self { true } else { false }
    }
}

nonisolated
struct ServicesCatalogItem: Identifiable, Equatable, Sendable {
    let route: ServicesRoute
    let guide: ServiceLabGuide

    var id: ServicesRoute { route }
}

nonisolated
enum ServiceLabGuideSection: String, CaseIterable, Identifiable, Sendable {
    case why
    case preset
    case tryIt
    case expected
    case actual
    case resetDemoData
    case advanced

    var id: Self { self }

    var title: String {
        switch self {
        case .why: "Why"
        case .preset: "Preset"
        case .tryIt: "Try It"
        case .expected: "Expected"
        case .actual: "Actual"
        case .resetDemoData: "Reset Demo Data"
        case .advanced: "Advanced"
        }
    }
}
