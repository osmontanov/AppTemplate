nonisolated
enum ExampleRecordCreationValidator {
    static func validateNewID(_ id: String) throws {
        guard !id.utf8.isEmpty, id.utf8.allSatisfy(isAllowed) else {
            throw ExampleRecordRepositoryError.invalidID
        }
    }

    private static func isAllowed(_ byte: UInt8) -> Bool {
        switch byte {
        case 97...122, 48...57, 45, 95, 46:
            true
        default:
            false
        }
    }
}
