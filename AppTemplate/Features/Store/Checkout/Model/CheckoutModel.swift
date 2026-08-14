import Foundation

nonisolated
enum CheckoutField: Hashable, Sendable {
    case recipient
    case address
    case note
}

nonisolated
struct CheckoutModel: Equatable, Sendable {
    private var recipientStorage: String
    private var addressStorage: String
    private var noteStorage: String

    static let fictionalPrefill = CheckoutModel(
        recipient: "Taylor Example",
        address: "42 Fictional Avenue",
        note: "Demo delivery only"
    )

    var recipient: String {
        get { recipientStorage }
        set { recipientStorage = Self.capped(newValue) }
    }
    var address: String {
        get { addressStorage }
        set { addressStorage = Self.capped(newValue) }
    }
    var note: String {
        get { noteStorage }
        set { noteStorage = Self.capped(newValue) }
    }

    init(recipient: String, address: String, note: String) {
        recipientStorage = Self.capped(recipient)
        addressStorage = Self.capped(address)
        noteStorage = Self.capped(note)
    }

    func firstInvalidField() -> CheckoutField? {
        if recipient.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .recipient }
        if address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .address }
        return nil
    }

    private static func capped(_ value: String) -> String {
        String(String.UnicodeScalarView(value.unicodeScalars.prefix(100)))
    }
}
