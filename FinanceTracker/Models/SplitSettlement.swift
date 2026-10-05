import Foundation
import SwiftData

/// Records a settlement payment between two members.
@Model
final class SplitSettlement {

    @Attribute(.unique) var id: UUID
    var fromMemberID: UUID
    var fromMemberName: String
    var toMemberID: UUID
    var toMemberName: String
    var amount: Double
    var date: Date
    var isPaid: Bool
    var note: String
    var createdAt: Date

    var ledger: Ledger?
    var group: SplitGroup?

    init(
        id: UUID = UUID(),
        fromMemberID: UUID,
        fromMemberName: String,
        toMemberID: UUID,
        toMemberName: String,
        amount: Double,
        date: Date = .now,
        isPaid: Bool = true,
        note: String = "",
        ledger: Ledger? = nil,
        group: SplitGroup? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.fromMemberID = fromMemberID
        self.fromMemberName = fromMemberName
        self.toMemberID = toMemberID
        self.toMemberName = toMemberName
        self.amount = (amount * 100).rounded() / 100.0
        self.date = date
        self.isPaid = isPaid
        self.note = note
        self.ledger = ledger
        self.group = group
        self.createdAt = createdAt
    }
}
