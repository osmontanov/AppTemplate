nonisolated
enum StoreInputLimits {
    static let maximumFieldScalars = 100

    static func capped(_ value: String) -> String {
        String(
            String.UnicodeScalarView(
                value.unicodeScalars.prefix(maximumFieldScalars)
            )
        )
    }
}
