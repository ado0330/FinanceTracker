import Foundation
import UserNotifications
import SwiftData

/// Manages local push notifications for the FinanceTracker app.
///
/// Responsibilities:
///   1. Request authorisation on first launch.
///   2. Schedule a one-shot alert when a budget is exceeded.
///   3. Cancel a pending notification when a budget is deleted or paused.
///   4. Fire daily budget-check notifications at a configurable hour.
///
/// All notification identifiers are deterministic (based on Budget.id) so
/// re-scheduling the same budget is idempotent (old request is replaced).
struct NotificationService {

    // MARK: - Notification Centre
    private static let center = UNUserNotificationCenter.current()

    // MARK: - Authorisation

    /// Request notification permission. Call once on app launch (idempotent).
    static func requestAuthorisation() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if !granted {
                print("📵 Notifications not authorised by user.")
            }
        } catch {
            print("❌ Notification authorisation error: \(error.localizedDescription)")
        }
    }

    // MARK: - Over-Budget Alert

    /// Fires an immediate local notification when `budget` has been exceeded.
    ///
    /// - Parameters:
    ///   - budget: The budget that was exceeded.
    ///   - spent: The actual amount spent (used in the message body).
    ///   - currencyCode: ISO 4217 code for formatting (e.g. "USD").
    static func scheduleOverBudgetAlert(for budget: Budget, spent: Double, currencyCode: String) {
        let content = UNMutableNotificationContent()
        content.title = "Budget Exceeded 🚨"
        content.body = "You've spent \(spent.currencyString(code: currencyCode)) on \(budget.category?.name ?? "this category"), which is over your \(budget.amount.currencyString(code: currencyCode)) \(budget.period.displayName.lowercased()) budget."
        content.sound = .defaultCritical
        content.categoryIdentifier = NotificationCategory.overBudget

        // Trigger immediately (nil trigger = fire right away)
        let request = UNNotificationRequest(
            identifier: overBudgetID(for: budget),
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error { print("❌ Failed to schedule notification: \(error.localizedDescription)") }
        }
    }

    // MARK: - Daily Budget-Check Reminder

    /// Schedules (or replaces) a daily notification at `hour` (24-hour, local time)
    /// reminding the user to check their budget.
    ///
    /// - Parameter hour: 0–23. Defaults to 20 (8 PM).
    static func scheduleDailyReminder(at hour: Int = 20, minute: Int = 0) {
        let content = UNMutableNotificationContent()
        content.title = "Budget Check-In 💰"
        content.body  = "Take a moment to review today's spending."
        content.sound = .default

        var components = DateComponents()
        components.hour   = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true
        )
        let request = UNNotificationRequest(
            identifier: NotificationID.dailyReminder,
            content: content,
            trigger: trigger
        )
        center.add(request) { error in
            if let error { print("❌ Daily reminder error: \(error.localizedDescription)") }
        }
    }

    static func cancelDailyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [NotificationID.dailyReminder])
    }

    // MARK: - Cancel helpers

    /// Cancels any pending over-budget alert for the given budget (e.g. on delete/pause).
    static func cancelOverBudgetAlert(for budget: Budget) {
        center.removePendingNotificationRequests(withIdentifiers: [overBudgetID(for: budget)])
    }

    /// Cancels all pending notifications scheduled by this app.
    static func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    // MARK: - Budget scan

    /// Scans all active budgets for the given ledger and fires alerts for any that are
    /// currently exceeded. Call after saving a new transaction.
    ///
    /// - Parameters:
    ///   - budgets:      Active budgets to check.
    ///   - transactions: The full transaction list for the ledger.
    ///   - currencyCode: ISO 4217 code for the ledger.
    static func checkBudgets(
        _ budgets: [Budget],
        transactions: [Transaction],
        currencyCode: String
    ) {
        for budget in budgets where budget.isActive {
            let spent = budget.spentAmount(in: transactions)
            if budget.isOverBudget(in: transactions) {
                scheduleOverBudgetAlert(for: budget, spent: spent, currencyCode: currencyCode)
            } else {
                // If no longer over budget (e.g. transaction was deleted),
                // cancel any lingering alert.
                cancelOverBudgetAlert(for: budget)
            }
        }
    }

    // MARK: - Private helpers

    private static func overBudgetID(for budget: Budget) -> String {
        "overbudget-\(budget.id.uuidString)"
    }
}

// MARK: - Constants

private enum NotificationID {
    static let dailyReminder = "com.local.FinanceTracker.dailyReminder"
}

private enum NotificationCategory {
    static let overBudget = "OVER_BUDGET"
}
