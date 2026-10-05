import XCTest
import SwiftData
@testable import FinanceTracker

@MainActor
final class SyncTests: XCTestCase {

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

    func testLedgerDTOSerialization() throws {
        let ledger = Ledger(name: "Family Vault", colorHex: "#1C1C1E", currency: "MYR", isDefault: true)
        context.insert(ledger)
        try context.save()

        let dto = LedgerDTO(from: ledger)
        XCTAssertEqual(dto.id, ledger.id)
        XCTAssertEqual(dto.name, "Family Vault")
        XCTAssertEqual(dto.currency, "MYR")
        XCTAssertTrue(dto.is_default)
        XCTAssertNil(dto.deleted_at)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(dto)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(LedgerDTO.self, from: data)
        XCTAssertEqual(decoded.id, ledger.id)
        XCTAssertEqual(decoded.name, "Family Vault")
    }

    func testTransactionDTOSoftDeleteAndMapping() throws {
        let ledger = Ledger(name: "Personal", currency: "MYR")
        let category = Category(name: "Dining", icon: "fork.knife", colorHex: "#FF9500", type: .expense)
        let account = Account(name: "Maybank", initialBalance: 1000.0)

        context.insert(ledger)
        context.insert(category)
        context.insert(account)

        let tx = Transaction(
            name: "Wagyu Don",
            amount: 78.50,
            type: .expense,
            date: .now,
            note: "Delicious dinner",
            ledger: ledger,
            category: category,
            account: account
        )
        context.insert(tx)
        try context.save()

        // Active DTO
        let activeDTO = TransactionDTO(from: tx)
        XCTAssertEqual(activeDTO.id, tx.id)
        XCTAssertEqual(activeDTO.name, "Wagyu Don")
        XCTAssertEqual(activeDTO.amount, 78.50)
        XCTAssertEqual(activeDTO.ledger_id, ledger.id)
        XCTAssertEqual(activeDTO.category_id, category.id)
        XCTAssertEqual(activeDTO.account_id, account.id)
        XCTAssertNil(activeDTO.deleted_at)

        // Soft deleted (tombstone) DTO
        let deletionTime = Date.now
        let tombstoneDTO = TransactionDTO(from: tx, deletedAt: deletionTime)
        XCTAssertNotNil(tombstoneDTO.deleted_at)
        XCTAssertEqual(tombstoneDTO.deleted_at, deletionTime)
    }

    func testSyncEngineStateTransitions() {
        let engine = SyncEngine()
        
        // Unconfigured initially if keys empty
        if engine.supabaseURL.isEmpty {
            XCTAssertEqual(engine.status, .notConfigured)
            XCTAssertFalse(engine.isConfigured)
        }

        // Test display texts and icons
        XCTAssertEqual(SyncEngine.SyncStatus.notConfigured.displayText, "Not Configured")
        XCTAssertEqual(SyncEngine.SyncStatus.notConfigured.iconName, "icloud.slash")

        XCTAssertEqual(SyncEngine.SyncStatus.idle.displayText, "Ready")
        XCTAssertEqual(SyncEngine.SyncStatus.idle.iconName, "cloud")

        XCTAssertEqual(SyncEngine.SyncStatus.syncing.displayText, "Syncing...")
        XCTAssertEqual(SyncEngine.SyncStatus.syncing.iconName, "arrow.triangle.2.circlepath")

        let date = Date.now
        XCTAssertTrue(SyncEngine.SyncStatus.synced(date).displayText.contains("Synced"))
        XCTAssertEqual(SyncEngine.SyncStatus.synced(date).iconName, "checkmark.icloud.fill")

        XCTAssertEqual(SyncEngine.SyncStatus.offline.displayText, "Offline")
        XCTAssertEqual(SyncEngine.SyncStatus.offline.iconName, "wifi.slash")
    }

    func testAccountAndBudgetDTOSerialization() throws {
        let account = Account(name: "Maybank Checking", institution: "Maybank", accountNumberLast4: "5678", initialBalance: 2500.0)
        context.insert(account)
        try context.save()

        let accDTO = AccountDTO(from: account)
        XCTAssertEqual(accDTO.id, account.id)
        XCTAssertEqual(accDTO.name, "Maybank Checking")
        XCTAssertEqual(accDTO.last_four, "5678")
        XCTAssertEqual(accDTO.starting_balance, 2500.0)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let accData = try encoder.encode(accDTO)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedAcc = try decoder.decode(AccountDTO.self, from: accData)
        XCTAssertEqual(decodedAcc.id, account.id)
        XCTAssertEqual(decodedAcc.last_four, "5678")
        XCTAssertEqual(decodedAcc.starting_balance, 2500.0)
    }

    func testDeduplicateAndReconcile() throws {
        // Create duplicate Personal ledgers: one empty, one with transactions
        let emptyLedger = Ledger(name: "Personal", isDefault: false)
        let activeLedger = Ledger(name: "Personal", isDefault: true)

        context.insert(emptyLedger)
        context.insert(activeLedger)

        let tx = Transaction(name: "Coffee", amount: 12.0, type: .expense, date: .now, ledger: activeLedger)
        context.insert(tx)
        try context.save()

        // Before deduplication: 2 ledgers
        let beforeLedgers = try context.fetch(FetchDescriptor<Ledger>())
        XCTAssertEqual(beforeLedgers.count, 2)

        // Run deduplicate and reconcile
        DataSeeder.deduplicateAndReconcile(context: context)

        // After deduplication: 1 ledger, containing the transaction
        let afterLedgers = try context.fetch(FetchDescriptor<Ledger>())
        XCTAssertEqual(afterLedgers.count, 1)
        XCTAssertEqual(afterLedgers.first?.id, activeLedger.id)
        XCTAssertEqual(afterLedgers.first?.transactions.count, 1)
    }
}
