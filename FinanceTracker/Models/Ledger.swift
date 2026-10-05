import Foundation
import SwiftData

/// A top-level account container separating financial contexts.
/// Examples: "Personal", "Family", "Business Trip".
@Model
final class Ledger {

    @Attribute(.unique) var id: UUID
    var name: String
    var icon: String        // SF Symbol name
    var colorHex: String    // "#RRGGBB"
    var currency: String    // ISO 4217 code, e.g. "USD", "MYR", "EUR"
    var isDefault: Bool     // The active ledger shown on launch
    var createdAt: Date

    // MARK: - Relationships

    /// All transactions belonging to this ledger.
    /// Delete rule: .cascade — removing a ledger removes all its transactions.
    @Relationship(deleteRule: .cascade, inverse: \Transaction.ledger)
    var transactions: [Transaction] = []

    /// Budgets scoped to this ledger.
    @Relationship(deleteRule: .cascade, inverse: \Budget.ledger)
    var budgets: [Budget] = []

    /// Recurring rules scoped to this ledger.
    @Relationship(deleteRule: .cascade, inverse: \RecurringRule.ledger)
    var recurringRules: [RecurringRule] = []

    // MARK: - Init

    init(
        name: String,
        icon: String     = "creditcard.fill",
        colorHex: String = "#1C1C1E",
        currency: String = "MYR",
        isDefault: Bool  = false
    ) {
        self.id        = UUID()
        self.name      = name
        self.icon      = icon
        self.colorHex  = colorHex
        self.currency  = currency
        self.isDefault = isDefault
        self.createdAt = .now
    }

    // MARK: - Computed Helpers

    var totalIncome: Double {
        transactions
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
    }

    var totalExpense: Double {
        transactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }

    var balance: Double { totalIncome - totalExpense }

    /// Income and expense totals filtered to the current calendar month.
    func monthlyTotals(for date: Date = .now) -> (income: Double, expense: Double) {
        let cal = Calendar.current
        let filtered = transactions.filter {
            cal.isDate($0.date, equalTo: date, toGranularity: .month)
        }
        let income  = filtered.filter { $0.type == .income  }.reduce(0) { $0 + $1.amount }
        let expense = filtered.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
        return (income, expense)
    }

    /// Income and expense totals filtered to the current calendar week.
    func weeklyTotals(for date: Date = .now) -> (income: Double, expense: Double) {
        let cal = Calendar.current
        let filtered = transactions.filter {
            cal.isDate($0.date, equalTo: date, toGranularity: .weekOfYear)
        }
        let income  = filtered.filter { $0.type == .income  }.reduce(0) { $0 + $1.amount }
        let expense = filtered.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
        return (income, expense)
    }
}
