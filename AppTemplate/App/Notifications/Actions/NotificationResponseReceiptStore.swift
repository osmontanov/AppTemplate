import Foundation

actor NotificationResponseReceiptStore {
    private let capacity: Int
    private var orderedReceipts: [NotificationResponseReceipt] = []
    private var receipts: Set<NotificationResponseReceipt> = []

    init(capacity: Int = 100) {
        precondition(capacity > 0, "Receipt capacity must be positive")
        self.capacity = capacity
    }

    func insertIfNew(_ receipt: NotificationResponseReceipt) -> Bool {
        guard receipts.insert(receipt).inserted else { return false }
        orderedReceipts.append(receipt)
        if orderedReceipts.count > capacity {
            let removed = orderedReceipts.removeFirst()
            receipts.remove(removed)
        }
        return true
    }
}
