import XCTest
import SwiftData
@testable import FinanceTracker

@MainActor
final class LedgerTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        container = try TestModelContainer.create()
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    func testLedgerBalanceAndTotals() {
        let ledger = Ledger(name: "Personal", currency: "USD")
        context.insert(ledger)

        let income = Transaction(amount: 2000.0, type: .income, date: .now, ledger: ledger)
        let expense = Transaction(amount: 450.0, type: .expense, date: .now, ledger: ledger)
        context.insert(income)
        context.insert(expense)
        try? context.save()

        XCTAssertEqual(ledger.totalIncome, 2000.0)
        XCTAssertEqual(ledger.totalExpense, 450.0)
        XCTAssertEqual(ledger.balance, 1550.0)
    }

    func testLedgerIsolation() {
        let personal = Ledger(name: "Personal", currency: "USD")
        let business = Ledger(name: "Business", currency: "EUR")
        context.insert(personal)
        context.insert(business)

        let personalTx = Transaction(amount: 500.0, type: .income, date: .now, ledger: personal)
        let businessTx = Transaction(amount: 1200.0, type: .income, date: .now, ledger: business)
        context.insert(personalTx)
        context.insert(businessTx)
        try? context.save()

        XCTAssertEqual(personal.balance, 500.0)
        XCTAssertEqual(business.balance, 1200.0)
        XCTAssertEqual(personal.transactions.count, 1)
        XCTAssertEqual(business.transactions.count, 1)
    }

    func testTransactionReceiptImageData() {
        let ledger = Ledger(name: "ReceiptTest", currency: "MYR")
        context.insert(ledger)

        let dummyImageData = "fake_receipt_png_data".data(using: .utf8)
        let txWithReceipt = Transaction(
            amount: 88.0,
            type: .expense,
            date: .now,
            note: "Dinner with receipt",
            ledger: ledger,
            receiptImageData: dummyImageData
        )
        context.insert(txWithReceipt)
        try? context.save()

        XCTAssertNotNil(txWithReceipt.receiptImageData)
        XCTAssertEqual(txWithReceipt.receiptImageData, dummyImageData)
    }

    func testTransactionNameAndDisplayName() {
        let ledger = Ledger(name: "NameTest", currency: "MYR")
        let category = Category(name: "Food & Dining", icon: "fork.knife", colorHex: "#FF9500", type: .expense)
        context.insert(ledger)
        context.insert(category)

        // Case 1: Transaction with specific name and food review note
        let foodTx = Transaction(
            name: "Curry Laksa",
            amount: 14.50,
            type: .expense,
            note: "Rich and spicy broth, tender chicken. 9/10!",
            ledger: ledger,
            category: category
        )
        XCTAssertEqual(foodTx.name, "Curry Laksa")
        XCTAssertEqual(foodTx.displayName, "Curry Laksa")
        XCTAssertEqual(foodTx.note, "Rich and spicy broth, tender chicken. 9/10!")

        // Case 2: Transaction with empty name, fallback to note
        let noteOnlyTx = Transaction(
            name: "",
            amount: 50.0,
            type: .expense,
            note: "Grab to airport",
            ledger: ledger,
            category: category
        )
        XCTAssertEqual(noteOnlyTx.displayName, "Grab to airport")

        // Case 3: Transaction with empty name and empty note, fallback to category name
        let blankTx = Transaction(
            name: "",
            amount: 20.0,
            type: .expense,
            note: "",
            ledger: ledger,
            category: category
        )
        XCTAssertEqual(blankTx.displayName, "Food & Dining")
    }

    func testCategoryMonthlyExpenseHighestFirstSorting() {
        let ledger = Ledger(name: "MonthlyExpenseTest", currency: "MYR")
        let foodCategory = Category(name: "Food & Dining", icon: "fork.knife", colorHex: "#FF9500", type: .expense)
        let transportCategory = Category(name: "Transport", icon: "car.fill", colorHex: "#5AC8FA", type: .expense)

        context.insert(ledger)
        context.insert(foodCategory)
        context.insert(transportCategory)

        let targetDate = Date.now
        let startOfMonth = targetDate.startOfMonth
        let endOfMonth = targetDate.endOfMonth

        // 3 Food expenses in current month with different amounts
        let food1 = Transaction(name: "Okan Ramen", amount: 35.0, type: .expense, date: targetDate, ledger: ledger, category: foodCategory)
        let food2 = Transaction(name: "Wagyu Steakhouse", amount: 280.0, type: .expense, date: targetDate, ledger: ledger, category: foodCategory)
        let food3 = Transaction(name: "Kopi & Toast", amount: 8.50, type: .expense, date: targetDate, ledger: ledger, category: foodCategory)

        // 1 Food expense in previous month (must NOT appear in current month)
        let prevMonthDate = Calendar.current.date(byAdding: .month, value: -1, to: targetDate)!
        let prevFood = Transaction(name: "Old Lunch", amount: 150.0, type: .expense, date: prevMonthDate, ledger: ledger, category: foodCategory)

        // 1 Transport expense in current month (must NOT appear in food category)
        let transport1 = Transaction(name: "Petrol Pump", amount: 95.0, type: .expense, date: targetDate, ledger: ledger, category: transportCategory)

        context.insert(food1)
        context.insert(food2)
        context.insert(food3)
        context.insert(prevFood)
        context.insert(transport1)
        try? context.save()

        // Filter current month expenses
        let currentMonthExpenses = ledger.transactions.filter {
            $0.type == .expense && $0.date >= startOfMonth && $0.date <= endOfMonth
        }

        // Filter Food category
        let foodExpenses = currentMonthExpenses.filter {
            $0.category?.name == "Food & Dining"
        }
        XCTAssertEqual(foodExpenses.count, 3)

        // Sort Highest First (User's requirement)
        let highestFirst = foodExpenses.sorted { $0.amount > $1.amount }
        XCTAssertEqual(highestFirst[0].name, "Wagyu Steakhouse")
        XCTAssertEqual(highestFirst[0].amount, 280.0)

        XCTAssertEqual(highestFirst[1].name, "Okan Ramen")
        XCTAssertEqual(highestFirst[1].amount, 35.0)

        XCTAssertEqual(highestFirst[2].name, "Kopi & Toast")
        XCTAssertEqual(highestFirst[2].amount, 8.50)

        // Filter Transport category
        let transportExpenses = currentMonthExpenses.filter {
            $0.category?.name == "Transport"
        }
        XCTAssertEqual(transportExpenses.count, 1)
        XCTAssertEqual(transportExpenses[0].name, "Petrol Pump")
        XCTAssertEqual(transportExpenses[0].amount, 95.0)
    }
}
