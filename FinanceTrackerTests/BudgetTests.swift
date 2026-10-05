import XCTest
import SwiftData
@testable import FinanceTracker

@MainActor
final class BudgetTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var ledger: Ledger!
    var category: Category!

    override func setUpWithError() throws {
        container = try TestModelContainer.create()
        context = container.mainContext
        ledger = Ledger(name: "Test Ledger", currency: "USD")
        category = Category(name: "Food", type: .expense)
        context.insert(ledger)
        context.insert(category)
        try context.save()
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
        ledger = nil
        category = nil
    }

    func testBudgetCalculations() {
        let budget = Budget(
            amount: 500.0,
            period: .monthly,
            ledger: ledger,
            category: category
        )
        context.insert(budget)

        // 1. Transaction within current month
        let tx1 = Transaction(amount: 150.0, type: .expense, date: .now, ledger: ledger, category: category)
        let tx2 = Transaction(amount: 100.0, type: .expense, date: .now, ledger: ledger, category: category)
        // 2. Transaction for a different category (should not count)
        let otherCat = Category(name: "Other", type: .expense)
        context.insert(otherCat)
        let tx3 = Transaction(amount: 80.0, type: .expense, date: .now, ledger: ledger, category: otherCat)

        let transactions = [tx1, tx2, tx3]

        let spent = budget.spentAmount(in: transactions)
        XCTAssertEqual(spent, 250.0)

        let remaining = budget.remainingAmount(in: transactions)
        XCTAssertEqual(remaining, 250.0)

        let ratio = budget.progressRatio(in: transactions)
        XCTAssertEqual(ratio, 0.5)

        XCTAssertFalse(budget.isOverBudget(in: transactions))

        // Exceed budget
        let txOver = Transaction(amount: 300.0, type: .expense, date: .now, ledger: ledger, category: category)
        let updatedTransactions = [tx1, tx2, tx3, txOver]

        XCTAssertTrue(budget.isOverBudget(in: updatedTransactions))
        XCTAssertEqual(budget.spentAmount(in: updatedTransactions), 550.0)
        XCTAssertEqual(budget.remainingAmount(in: updatedTransactions), 0.0)
        XCTAssertEqual(budget.progressRatio(in: updatedTransactions), 1.0)
    }
}
