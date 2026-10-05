import Foundation
import SwiftData

/// A template that the RecurringService uses to auto-generate transactions on a schedule.
/// Examples: Netflix subscription (monthly), gym membership (monthly), bus pass (weekly).
@Model
final class RecurringRule {

    @Attribute(.unique) var id: UUID
    var amount: Double
    var type: TransactionType          // .income or .expense
    var note: String                   // Description shown on generated transactions
    var frequency: RecurringFrequency
    var startDate: Date
    var nextDueDate: Date              // The next date a transaction should be generated
    var endDate: Date?                 // nil = runs indefinitely
    var isActive: Bool
    var createdAt: Date

    // MARK: - Relationships

    /// Owning side declared on Ledger.recurringRules.
    var ledger: Ledger?

    /// Owning side declared on Category.recurringRules.
    var category: Category?

    // MARK: - Init

    init(
        amount: Double,
        type: TransactionType         = .expense,
        note: String                  = "",
        frequency: RecurringFrequency = .monthly,
        startDate: Date               = .now,
        endDate: Date?                = nil,
        ledger: Ledger?               = nil,
        category: Category?           = nil
    ) {
        self.id          = UUID()
        self.amount      = amount
        self.type        = type
        self.note        = note
        self.frequency   = frequency
        self.startDate   = startDate
        self.nextDueDate = startDate
        self.endDate     = endDate
        self.isActive    = true
        self.ledger      = ledger
        self.category    = category
        self.createdAt   = .now
    }

    // MARK: - Scheduling Helpers

    /// Returns `true` when the rule should fire and generate a transaction today.
    var isDue: Bool {
        guard isActive else { return false }
        if let end = endDate, Date.now > end { return false }
        return Date.now >= nextDueDate
    }

    /// Advance `nextDueDate` forward by one frequency period.
    /// Called by RecurringService immediately after generating a transaction.
    func advanceNextDueDate() {
        let (component, value) = frequency.calendarAdvance
        nextDueDate = Calendar.current.date(
            byAdding: component,
            value: value,
            to: nextDueDate
        ) ?? nextDueDate
    }

    /// Builds the Transaction that should be created when this rule fires.
    func makeTransaction() -> Transaction {
        Transaction(
            name:            !note.isEmpty ? note : (category?.name ?? "Recurring Payment"),
            amount:          amount,
            type:            type,
            date:            nextDueDate,
            note:            note,
            ledger:          ledger,
            category:        category,
            recurringRuleID: id
        )
    }
}
