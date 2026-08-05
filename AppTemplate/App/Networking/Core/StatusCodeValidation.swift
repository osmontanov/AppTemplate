nonisolated
enum StatusCodeValidation: Sendable {
    case successful
    case successfulAndRedirects
    case range(Range<Int>)
    case none

    func accepts(_ statusCode: Int) -> Bool {
        switch self {
        case .successful:
            (200..<300).contains(statusCode)
        case .successfulAndRedirects:
            (200..<400).contains(statusCode)
        case let .range(range):
            range.contains(statusCode)
        case .none:
            true
        }
    }
}
