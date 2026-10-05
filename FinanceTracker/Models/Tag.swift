import Foundation
import SwiftData

/// A free-form label that can be applied to any number of transactions (many-to-many).
/// Examples: "Business Trip", "Tax-Deductible", "Reimbursable".
@Model
final class Tag {

    @Attribute(.unique) var id: UUID
    var name: String
    var icon: String        // SF Symbol name
    var colorHex: String   // "#RRGGBB"
    var isSystem: Bool     // system-seeded tags cannot be deleted
    var sortOrder: Int
    var createdAt: Date

    // MARK: - Relationships

    /// The many-to-many relationship is owned by Transaction.tags (via @Relationship there).
    /// SwiftData requires the inverse side to declare the property; no annotation needed here.
    var transactions: [Transaction] = []

    // MARK: - Init

    init(
        name: String,
        icon: String     = "tag.fill",
        colorHex: String = "#FFD700",
        isSystem: Bool   = false,
        sortOrder: Int   = 0
    ) {
        self.id        = UUID()
        self.name      = name
        self.icon      = icon
        self.colorHex  = colorHex
        self.isSystem  = isSystem
        self.sortOrder = sortOrder
        self.createdAt = .now
    }
}
