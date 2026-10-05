import Foundation
import SwiftData

/// A user-defined spending or income category (e.g. Food, Salary, Transport).
/// Marked `isSystem = true` for seed data that cannot be deleted.
@Model
final class Category {

    @Attribute(.unique) var id: UUID
    var name: String
    var icon: String        // SF Symbol name
    var colorHex: String    // "#RRGGBB"
    var type: CategoryType  // income / expense / both
    var isSystem: Bool      // system-seeded rows cannot be deleted
    var sortOrder: Int
    var createdAt: Date

    // MARK: - Relationships

    /// All transactions tagged with this category.
    /// Delete rule: .nullify — deleting a category does NOT delete historical transactions.
    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction] = []

    /// Budgets configured for this category.
    /// Delete rule: .cascade — a budget without a category is meaningless.
    @Relationship(deleteRule: .cascade, inverse: \Budget.category)
    var budgets: [Budget] = []

    /// Recurring rules that auto-generate transactions under this category.
    /// Delete rule: .nullify — preserve the rule but clear the category reference.
    @Relationship(deleteRule: .nullify, inverse: \RecurringRule.category)
    var recurringRules: [RecurringRule] = []

    // MARK: - Init

    init(
        name: String,
        icon: String        = "tag.fill",
        colorHex: String    = "#A0A0A0",
        type: CategoryType  = .expense,
        isSystem: Bool      = false,
        sortOrder: Int      = 0
    ) {
        self.id        = UUID()
        self.name      = name
        self.icon      = icon
        self.colorHex  = colorHex
        self.type      = type
        self.isSystem  = isSystem
        self.sortOrder = sortOrder
        self.createdAt = .now
    }
}
