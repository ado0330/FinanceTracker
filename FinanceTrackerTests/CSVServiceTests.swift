import XCTest
import SwiftData
@testable import FinanceTracker

@MainActor
final class CSVServiceTests: XCTestCase {

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

    // MARK: - Export Tests

    func testCSVExport() {
        let category = Category(name: "Dining, Out", type: .expense)
        let tag1 = Tag(name: "Food")
        let tag2 = Tag(name: "Dinner")
        context.insert(category)
        context.insert(tag1)
        context.insert(tag2)

        let tx = Transaction(
            amount: 45.50,
            type: .expense,
            date: Date(timeIntervalSince1970: 1700000000),
            note: "Celebration, with \"special\" guests\nLine 2",
            ledger: ledger,
            category: category,
            tags: [tag1, tag2]
        )
        context.insert(tx)
        try? context.save()

        let csv = CSVService.exportCSV(transactions: [tx], currencyCode: "USD")
        let lines = csv.components(separatedBy: "\n")

        XCTAssertTrue(lines[0].starts(with: "Date,Type,Category,Amount,Note,Tags,RecurringRuleID"))
        XCTAssertTrue(csv.contains("\"Dining, Out\""))
        XCTAssertTrue(csv.contains("45.50"))
        XCTAssertTrue(csv.contains("Celebration, with \"\"special\"\" guests"))
    }

    // MARK: - Import Tests

    func testCSVImportBasic() {
        let csvData = """
        Date,Type,Category,Amount,Note,Tags,RecurringRuleID
        2026-03-15 14:30:00,expense,Groceries,75.25,Weekly supermarket,Food;Home,
        2026-03-16 09:00:00,income,Salary,3500.00,Monthly paycheck,Job,
        """

        let outcome = CSVService.importCSV(from: csvData, ledger: ledger, context: context)

        XCTAssertEqual(outcome.imported, 2)
        XCTAssertEqual(outcome.errors.count, 0)

        let fetchDescriptor = FetchDescriptor<Transaction>()
        let txs = (try? context.fetch(fetchDescriptor)) ?? []
        XCTAssertEqual(txs.count, 2)

        let groceryTx = txs.first { $0.note == "Weekly supermarket" }
        XCTAssertNotNil(groceryTx)
        XCTAssertEqual(groceryTx?.type, .expense)
        XCTAssertEqual(groceryTx?.amount, 75.25)
        XCTAssertEqual(groceryTx?.category?.name, "Groceries")
        XCTAssertEqual(groceryTx?.tags.count, 2)

        let salaryTx = txs.first { $0.note == "Monthly paycheck" }
        XCTAssertNotNil(salaryTx)
        XCTAssertEqual(salaryTx?.type, .income)
        XCTAssertEqual(salaryTx?.amount, 3500.00)
    }

    func testCSVImportMultipleDateFormats() {
        let csvData = """
        Date,Type,Category,Amount,Note
        2026-05-20,expense,Transport,12.50,Date only YMD
        05/22/2026,expense,Transport,15.00,Date only MDY
        2026-05-23T18:00:00Z,expense,Transport,20.00,ISO format
        """

        let outcome = CSVService.importCSV(from: csvData, ledger: ledger, context: context)
        XCTAssertEqual(outcome.imported, 3)
        XCTAssertEqual(outcome.errors.count, 0)
    }

    func testCSVImportErrorHandling() {
        let csvData = """
        Date,Type,Category,Amount,Note
        invalid-date,expense,Food,10.00,Invalid date
        2026-01-01 12:00:00,unknown_type,Food,10.00,Invalid type
        2026-01-01 12:00:00,expense,Food,not_a_number,Invalid amount
        """

        let outcome = CSVService.importCSV(from: csvData, ledger: ledger, context: context)
        XCTAssertEqual(outcome.imported, 0)
        XCTAssertEqual(outcome.errors.count, 3)
    }
}
