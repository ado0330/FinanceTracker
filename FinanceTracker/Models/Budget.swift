import Foundation
import SwiftData

/// A spending cap for a specific category within a ledger over a given period.
/// When actual spending exceeds `amount`, the NotificationService fires a local alert.
@Model
final class Budget {

    @Attribute(.unique) var id: UUID
    var amount: Double            // Spending cap
    var period: BudgetPeriod      // .weekly or .monthly
    var startDate: Date           // When this budget became active
    var isActive: Bool
    var createdAt: Date

    // MARK: - Relationships

    /// Owning side declared on Ledger.budgets.
    var ledger: Ledger?

    /// Owning side declared on Category.budgets.
    var category: Category?

    // MARK: - Init

    init(
        amount: Double,
        period: BudgetPeriod = .monthly,
        startDate: Date      = .now,
        ledger: Ledger?      = nil,
        category: Category?  = nil
    ) {
        self.id        = UUID()
        self.amount    = amount
        self.period    = period
        self.startDate = startDate
        self.isActive  = true
        self.ledger    = ledger
        self.category  = category
        self.createdAt = .now
    }

    // MARK: - Spending Calculations
    //
    // These accept an external transaction array so the model stays free of
    // query logic. The BudgetViewModel supplies the relevant transactions.

    /// Total expense amount spent in the current period for this budget's category.
    func spentAmount(in transactions: [Transaction]) -> Double {
        let now = Date.now
        let cal = Calendar.current
        return transactions
            .filter { t in
                guard t.type == .expense else { return false }
                guard let tCat = t.category, let bCat = category else { return false }
                guard tCat.id == bCat.id else { return false }
                switch period {
                case .monthly: return cal.isDate(t.date, equalTo: now, toGranularity: .month)
                case .weekly:  return cal.isDate(t.date, equalTo: now, toGranularity: .weekOfYear)
                }
            }
            .reduce(0) { $0 + $1.amount }
    }

    /// Ratio 0.0…1.0 (clamped). Drives the progress bar in the UI.
    func progressRatio(in transactions: [Transaction]) -> Double {
        guard amount > 0 else { return 0 }
        return min(spentAmount(in: transactions) / amount, 1.0)
    }

    func isOverBudget(in transactions: [Transaction]) -> Bool {
        spentAmount(in: transactions) > amount
    }

    func remainingAmount(in transactions: [Transaction]) -> Double {
        max(amount - spentAmount(in: transactions), 0)
    }
}
