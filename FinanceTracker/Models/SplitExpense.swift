import Foundation
import SwiftData

/// Represents a shared group expense record with payer and share breakdowns.
@Model
final class SplitExpense {

    @Attribute(.unique) var id: UUID
    var title: String
    var totalAmount: Double
    var date: Date
    var note: String
    var splitModeRaw: String
    var taxAmount: Double
    var serviceFeeAmount: Double
    var roundingAmount: Double = 0.0
    var isSettled: Bool
    var createdAt: Date

    @Attribute(.externalStorage) var receiptImageData: Data?

    var payersData: Data?
    var sharesData: Data?
    var receiptItemsData: Data?

    var ledger: Ledger?
    var group: SplitGroup?

    init(
        id: UUID = UUID(),
        title: String,
        totalAmount: Double,
        date: Date = .now,
        note: String = "",
        splitMode: SplitMode = .equal,
        taxAmount: Double = 0.0,
        serviceFeeAmount: Double = 0.0,
        roundingAmount: Double = 0.0,
        isSettled: Bool = false,
        receiptImageData: Data? = nil,
        payers: [SplitPayer] = [],
        shares: [SplitShare] = [],
        receiptItems: [ReceiptLineItem] = [],
        ledger: Ledger? = nil,
        group: SplitGroup? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.totalAmount = (totalAmount * 100).rounded() / 100.0
        self.date = date
        self.note = note
        self.splitModeRaw = splitMode.rawValue
        self.taxAmount = (taxAmount * 100).rounded() / 100.0
        self.serviceFeeAmount = (serviceFeeAmount * 100).rounded() / 100.0
        self.roundingAmount = (roundingAmount * 100).rounded() / 100.0
        self.isSettled = isSettled
        self.receiptImageData = receiptImageData
        self.ledger = ledger
        self.group = group
        self.createdAt = createdAt

        self.payers = payers
        self.shares = shares
        self.receiptItems = receiptItems
    }

    // MARK: - Computed Properties

    var splitMode: SplitMode {
        get { SplitMode(rawValue: splitModeRaw) ?? .equal }
        set { splitModeRaw = newValue.rawValue }
    }

    var payers: [SplitPayer] {
        get {
            guard let data = payersData else { return [] }
            return (try? JSONDecoder().decode([SplitPayer].self, from: data)) ?? []
        }
        set {
            payersData = try? JSONEncoder().encode(newValue)
        }
    }

    var shares: [SplitShare] {
        get {
            guard let data = sharesData else { return [] }
            return (try? JSONDecoder().decode([SplitShare].self, from: data)) ?? []
        }
        set {
            sharesData = try? JSONEncoder().encode(newValue)
        }
    }

    var receiptItems: [ReceiptLineItem] {
        get {
            guard let data = receiptItemsData else { return [] }
            return (try? JSONDecoder().decode([ReceiptLineItem].self, from: data)) ?? []
        }
        set {
            receiptItemsData = try? JSONEncoder().encode(newValue)
        }
    }
}
