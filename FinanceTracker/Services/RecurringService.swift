import Foundation
import SwiftData

/// Scans all overdue `RecurringRule` records and generates the corresponding
/// `Transaction` objects. Called once on cold app launch from `ContentView.task`.
///
/// Design decisions:
///   - Stateless struct — no stored state, all context is passed in.
///   - A rule can generate **multiple** transactions in one pass if it missed
///     several periods (e.g. the user didn't open the app for 3 months).
///   - Each generated transaction carries the rule's `id` in `recurringRuleID`
///     so history is preserved even if the rule is later deleted.
///   - `nextDueDate` is advanced inside the loop so progress is always saved.
///   - The caller passes in the `ModelContext` directly; the service does
///     not fetch from it to keep tests fast.
struct RecurringService {

    // MARK: - Main entry point

    /// Process all overdue rules for every ledger in the store.
    ///
    /// - Parameter context: The live `ModelContext` to insert transactions into.
    /// - Returns: The number of transactions generated.
    @discardableResult
    static func processOverdue(context: ModelContext) -> Int {
        // Fetch all active rules ordered by nextDueDate (oldest first).
        var descriptor = FetchDescriptor<RecurringRule>(
            predicate: #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\RecurringRule.nextDueDate)]
        )
        descriptor.fetchLimit = 500      // safety cap

        guard let rules = try? context.fetch(descriptor) else { return 0 }

        let now = Date.now
        var generatedCount = 0

        for rule in rules {
            generatedCount += generateTransactions(for: rule, upTo: now, context: context)
        }

        if generatedCount > 0 {
            try? context.save()
            print("✅ RecurringService: generated \(generatedCount) transaction(s).")
        }

        return generatedCount
    }

    // MARK: - Per-rule generation

    /// Generates one transaction per overdue period for `rule`, advancing
    /// `nextDueDate` each time. Stops when the rule is no longer due or
    /// passes its `endDate`.
    ///
    /// - Returns: Number of transactions generated for this rule.
    @discardableResult
    private static func generateTransactions(
        for rule: RecurringRule,
        upTo now: Date,
        context: ModelContext
    ) -> Int {
        var count = 0
        // Guard against infinite loops from bad data — cap at 366 iterations.
        var safetyCounter = 0

        while rule.isDue && rule.nextDueDate <= now && safetyCounter < 366 {
            safetyCounter += 1

            // Build and insert the transaction.
            let transaction = rule.makeTransaction()
            context.insert(transaction)
            count += 1

            // Advance the schedule. This mutates rule.nextDueDate directly on
            // the model — SwiftData will persist the change on the next save.
            rule.advanceNextDueDate()

            // If advancing pushed us past the endDate, deactivate the rule.
            if let end = rule.endDate, rule.nextDueDate > end {
                rule.isActive = false
                break
            }
        }

        return count
    }

    // MARK: - Manual trigger

    /// Manually mark a rule as processed without generating a transaction.
    /// Useful for rules the user wants to skip once (e.g. waived payment).
    static func skipCurrentPeriod(for rule: RecurringRule, context: ModelContext) {
        rule.advanceNextDueDate()
        try? context.save()
    }
}
