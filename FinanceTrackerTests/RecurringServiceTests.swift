import XCTest
import SwiftData
@testable import FinanceTracker

@MainActor
final class RecurringServiceTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var ledger: Ledger!

    override func setUpWithError() throws {
        container = try TestModelContainer.create()
        context = container.mainContext
        ledger = Ledger(name: "Test Ledger", currency: "USD")
        context.insert(ledger)
        try context.save()
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
        ledger = nil
    }

    func testAdvanceNextDueDate() {
        let baseDate = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15))!

        let dailyRule = RecurringRule(amount: 10, note: "Daily", frequency: .daily, startDate: baseDate)
        dailyRule.advanceNextDueDate()
        XCTAssertEqual(Calendar.current.component(.day, from: dailyRule.nextDueDate), 16)

        let monthlyRule = RecurringRule(amount: 10, note: "Monthly", frequency: .monthly, startDate: baseDate)
        monthlyRule.advanceNextDueDate()
        XCTAssertEqual(Calendar.current.component(.month, from: monthlyRule.nextDueDate), 2)
        XCTAssertEqual(Calendar.current.component(.day, from: monthlyRule.nextDueDate), 15)

        let yearlyRule = RecurringRule(amount: 10, note: "Yearly", frequency: .yearly, startDate: baseDate)
        yearlyRule.advanceNextDueDate()
        XCTAssertEqual(Calendar.current.component(.year, from: yearlyRule.nextDueDate), 2027)
    }

    func testProcessOverdueSingleTransaction() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let rule = RecurringRule(
            amount: 100.0,
            type: .expense,
            note: "Internet Bill",
            frequency: .monthly,
            startDate: yesterday,
            ledger: ledger
        )
        context.insert(rule)
        try? context.save()

        let logged = RecurringService.processOverdue(context: context)
        XCTAssertEqual(logged, 1)

        let txs = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        XCTAssertEqual(txs.count, 1)
        XCTAssertEqual(txs.first?.amount, 100.0)
        XCTAssertEqual(txs.first?.recurringRuleID, rule.id)
        XCTAssertTrue(rule.nextDueDate > Date.now)
    }

    func testProcessOverdueMultiPeriodCatchup() {
        let threeWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -3, to: .now)!
        let rule = RecurringRule(
            amount: 50.0,
            type: .expense,
            note: "Weekly Meal Plan",
            frequency: .weekly,
            startDate: threeWeeksAgo,
            ledger: ledger
        )
        context.insert(rule)
        try? context.save()

        let logged = RecurringService.processOverdue(context: context)
        XCTAssertGreaterThanOrEqual(logged, 3)

        let txs = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        XCTAssertEqual(txs.count, logged)
        XCTAssertTrue(rule.nextDueDate > Date.now)
    }

    func testSkipCurrentPeriod() {
        let initialDue = Date.now
        let rule = RecurringRule(
            amount: 25.0,
            type: .expense,
            note: "Gym Membership",
            frequency: .monthly,
            startDate: initialDue,
            ledger: ledger
        )
        context.insert(rule)
        try? context.save()

        RecurringService.skipCurrentPeriod(for: rule, context: context)

        let txs = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        XCTAssertEqual(txs.count, 0)
        XCTAssertTrue(rule.nextDueDate > initialDue)
    }
}
