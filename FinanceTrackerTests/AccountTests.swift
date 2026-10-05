import XCTest
import SwiftData
@testable import FinanceTracker

@MainActor
final class AccountTests: XCTestCase {

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

    func testAccountCreationAndProperties() {
        let account = Account(
            name: "Main Checking",
            institution: "Maybank",
            accountType: .bank,
            accountNumberLast4: "4821",
            initialBalance: 1500.0,
            currency: "MYR",
            colorHex: "#1C1C1E",
            icon: "building.columns.fill",
            isDefault: true
        )
        context.insert(account)

        XCTAssertEqual(account.name, "Main Checking")
        XCTAssertEqual(account.institution, "Maybank")
        XCTAssertEqual(account.accountType, .bank)
        XCTAssertEqual(account.accountNumberLast4, "4821")
        XCTAssertEqual(account.maskedNumberDisplay, "•••• 4821")
        XCTAssertEqual(account.fullDisplayName, "Maybank · Main Checking")
        XCTAssertEqual(account.currentBalance, 1500.0)
        XCTAssertTrue(account.isDefault)
    }

    func testBankAccountBalanceWithTransactions() {
        let ledger = Ledger(name: "Personal")
        context.insert(ledger)

        let bankAccount = Account(
            name: "Maybank",
            institution: "Maybank",
            accountType: .bank,
            initialBalance: 5000.0,
            currency: "MYR"
        )
        context.insert(bankAccount)

        let salaryTx = Transaction(
            amount: 2500.0,
            type: .income,
            date: .now,
            note: "Monthly Salary",
            ledger: ledger,
            account: bankAccount
        )
        let groceriesTx = Transaction(
            amount: 350.0,
            type: .expense,
            date: .now,
            note: "Groceries",
            ledger: ledger,
            account: bankAccount
        )
        context.insert(salaryTx)
        context.insert(groceriesTx)

        XCTAssertEqual(bankAccount.totalIncome, 2500.0)
        XCTAssertEqual(bankAccount.totalExpense, 350.0)
        // 5000 initial + 2500 income - 350 expense = 7150
        XCTAssertEqual(bankAccount.currentBalance, 7150.0)
    }

    func testCreditCardBalanceWithTransactions() {
        let ledger = Ledger(name: "Personal")
        context.insert(ledger)

        let creditCard = Account(
            name: "Visa Platinum",
            institution: "CIMB",
            accountType: .creditCard,
            initialBalance: 0.0,
            currency: "MYR"
        )
        context.insert(creditCard)

        // Spending on credit card increases debt
        let purchaseTx = Transaction(
            amount: 420.0,
            type: .expense,
            date: .now,
            note: "Online Shopping",
            ledger: ledger,
            account: creditCard
        )
        context.insert(purchaseTx)

        // Payment towards credit card decreases debt
        let paymentTx = Transaction(
            amount: 120.0,
            type: .income,
            date: .now,
            note: "Card Payment",
            ledger: ledger,
            account: creditCard
        )
        context.insert(paymentTx)

        // For credit cards, balance = initial (0) + expense (420) - income (120) = 300 debt
        XCTAssertEqual(creditCard.currentBalance, 300.0)
    }

    func testAccountReconciliation() {
        let ledger = Ledger(name: "Personal")
        context.insert(ledger)

        let bankAccount = Account(
            name: "Savings",
            institution: "RHB",
            accountType: .savings,
            initialBalance: 1000.0,
            currency: "MYR"
        )
        context.insert(bankAccount)

        let tx = Transaction(
            amount: 200.0,
            type: .expense,
            date: .now,
            ledger: ledger,
            account: bankAccount
        )
        context.insert(tx)

        // Balance before: 1000 - 200 = 800
        XCTAssertEqual(bankAccount.currentBalance, 800.0)

        // User reconciles to 1500 based on actual bank statement
        bankAccount.reconcile(to: 1500.0)
        XCTAssertEqual(bankAccount.currentBalance, 1500.0)
    }

    func testTotalBankMoneyAndNetWorthCalculation() {
        let maybank = Account(name: "Checking", institution: "Maybank", accountType: .bank, initialBalance: 5000.0)
        let cimb = Account(name: "Savings", institution: "CIMB", accountType: .savings, initialBalance: 10000.0)
        let cash = Account(name: "Pocket Cash", institution: "Cash", accountType: .cash, initialBalance: 500.0)
        let creditCard = Account(name: "Amex", institution: "Maybank", accountType: .creditCard, initialBalance: 1500.0)

        context.insert(maybank)
        context.insert(cimb)
        context.insert(cash)
        context.insert(creditCard)

        let all = [maybank, cimb, cash, creditCard]

        // Bank Money (checking + savings) = 5,000 + 10,000 = 15,000
        let totalBank = all
            .filter { $0.accountType == .bank || $0.accountType == .savings }
            .reduce(0) { $0 + $1.currentBalance }
        XCTAssertEqual(totalBank, 15000.0)

        // Assets = 5,000 + 10,000 + 500 = 15,500
        let totalAssets = all
            .filter { $0.accountType.isAsset }
            .reduce(0) { $0 + $1.currentBalance }
        XCTAssertEqual(totalAssets, 15500.0)

        // Liabilities = 1,500
        let totalLiabilities = all
            .filter { !$0.accountType.isAsset }
            .reduce(0) { $0 + $1.currentBalance }
        XCTAssertEqual(totalLiabilities, 1500.0)

        // Net Worth = 15,500 - 1,500 = 14,000
        XCTAssertEqual(totalAssets - totalLiabilities, 14000.0)
    }

    func testAccountDeletionNullifiesTransactionAccount() throws {
        let ledger = Ledger(name: "Personal")
        context.insert(ledger)

        let account = Account(name: "Maybank", accountType: .bank, initialBalance: 100.0)
        context.insert(account)

        let tx = Transaction(amount: 50.0, type: .expense, date: .now, ledger: ledger, account: account)
        context.insert(tx)

        try context.save()
        XCTAssertEqual(tx.account?.id, account.id)

        // Delete account
        context.delete(account)
        try context.save()

        // Transaction should still exist with null account
        XCTAssertNil(tx.account)
        XCTAssertEqual(tx.amount, 50.0)
    }
}
