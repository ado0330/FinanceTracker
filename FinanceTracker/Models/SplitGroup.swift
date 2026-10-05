import Foundation
import SwiftData

/// Represents an isolated group (e.g. "Penang Trip", "Roommates", "Family") for splitting expenses.
@Model
final class SplitGroup {

    @Attribute(.unique) var id: UUID
    var name: String
    var icon: String
    var colorHex: String
    var isDefault: Bool
    var createdAt: Date

    var ledger: Ledger?

    @Relationship(deleteRule: .cascade, inverse: \SplitMember.group)
    var members: [SplitMember] = []

    @Relationship(deleteRule: .cascade, inverse: \SplitExpense.group)
    var expenses: [SplitExpense] = []

    @Relationship(deleteRule: .cascade, inverse: \SplitSettlement.group)
    var settlements: [SplitSettlement] = []

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "person.3.fill",
        colorHex: String = "#1C1C1E",
        isDefault: Bool = false,
        createdAt: Date = .now,
        ledger: Ledger? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.isDefault = isDefault
        self.createdAt = createdAt
        self.ledger = ledger
    }

    /// Total unsettled expense amount for this group
    var unsettledTotal: Double {
        expenses.filter { !$0.isSettled }.reduce(0.0) { $0 + $1.totalAmount }
    }
}
