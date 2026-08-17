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
        set { recipientStorage = StoreInputLimits.capped(newValue) }
    }
    var address: String {
        get { addressStorage }
        set { addressStorage = StoreInputLimits.capped(newValue) }
    }
    var note: String {
        get { noteStorage }
        set { noteStorage = StoreInputLimits.capped(newValue) }
    }

    init(recipient: String, address: String, note: String) {
        recipientStorage = StoreInputLimits.capped(recipient)
        addressStorage = StoreInputLimits.capped(address)
        noteStorage = StoreInputLimits.capped(note)
    }

    func firstInvalidField() -> CheckoutField? {
        if recipient.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .recipient }
        if address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .address }
        return nil
    }
}
