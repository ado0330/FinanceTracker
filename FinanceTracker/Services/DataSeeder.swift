import Foundation
import SwiftData

/// Seeds one default "Personal" ledger and a full set of system categories
/// on the very first app launch. Subsequent launches are no-ops.
struct DataSeeder {

    // MARK: - Public Entry Point

    static func seedIfNeeded(context: ModelContext) {
        // Guard: only seed when no ledgers exist at all
        let descriptor = FetchDescriptor<Ledger>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        if existingCount > 0 {
            migrateExistingDataIfNeeded(context: context)
            return
        }

        // Default ledger
        let personal = Ledger(
            name:      "Personal",
            icon:      "person.fill",
            colorHex:  "#1C1C1E",
            currency:  "MYR",
            isDefault: true
        )
        context.insert(personal)

        // System expense categories
        let expenseItems: [(name: String, icon: String, hex: String)] = [
            ("Food & Dining",     "fork.knife",               "#FF6B6B"),
            ("Transport",         "car.fill",                 "#4ECDC4"),
            ("Shopping",          "bag.fill",                 "#45B7D1"),
            ("Bills & Utilities", "bolt.fill",                "#96CEB4"),
            ("Entertainment",     "ticket.fill",              "#F6C90E"),
            ("Health & Medical",  "cross.fill",               "#DDA0DD"),
            ("Education",         "book.fill",                "#98D8C8"),
            ("Travel",            "airplane",                 "#F7DC6F"),
            ("Housing",           "house.fill",               "#85C1E9"),
            ("Other",             "ellipsis.circle.fill",     "#A0A0A0"),
        ]

        for (idx, item) in expenseItems.enumerated() {
            context.insert(Category(
                name:      item.name,
                icon:      item.icon,
                colorHex:  item.hex,
                type:      .expense,
                isSystem:  true,
                sortOrder: idx
            ))
        }

        // System income categories
        let incomeItems: [(name: String, icon: String, hex: String)] = [
            ("Salary",        "briefcase.fill",            "#2ECC71"),
            ("Freelance",     "laptopcomputer",            "#27AE60"),
            ("Investment",    "chart.line.uptrend.xyaxis", "#F39C12"),
            ("Gift",          "gift.fill",                 "#E74C3C"),
            ("Other Income",  "plus.circle.fill",          "#3498DB"),
        ]

        for (idx, item) in incomeItems.enumerated() {
            context.insert(Category(
                name:      item.name,
                icon:      item.icon,
                colorHex:  item.hex,
                type:      .income,
                isSystem:  true,
                sortOrder: idx
            ))
        }

        // System default tags
        let tagItems: [(name: String, icon: String, hex: String)] = [
            ("Business",        "briefcase.fill",   "#5A8BDF"),
            ("Tax-Deductible",  "doc.text.fill",    "#2ECC71"),
            ("Personal",        "person.fill",      "#9B59B6"),
            ("Reimbursable",    "arrow.clockwise",  "#E67E22"),
            ("Vacation",        "airplane",         "#1ABC9C")
        ]

        for (idx, item) in tagItems.enumerated() {
            context.insert(Tag(
                name:      item.name,
                icon:      item.icon,
                colorHex:  item.hex,
                isSystem:  true,
                sortOrder: idx
            ))
        }

        // Seed default bank account
        let defaultAccount = Account(
            name: "Main Checking",
            institution: "Maybank",
            accountType: .bank,
            accountNumberLast4: "4821",
            initialBalance: 0.0,
            currency: "MYR",
            colorHex: "#1C1C1E",
            icon: "building.columns.fill",
            isDefault: true
        )
        context.insert(defaultAccount)

        try? context.save()
    }

    // MARK: - v1.1 Migration

    /// Automatically migrates existing installs from USD to MYR if not already done.
    static func migrateExistingDataIfNeeded(context: ModelContext) {
        let migrationKey = "hasMigratedToMYR_v1_1"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        UserDefaults.standard.set(true, forKey: migrationKey)

        let descriptor = FetchDescriptor<Ledger>()
        if let ledgers = try? context.fetch(descriptor) {
            for ledger in ledgers {
                if ledger.currency == "USD" {
                    ledger.currency = "MYR"
                }
                if ledger.isDefault && (ledger.colorHex == "#2ECC71" || ledger.colorHex == "#4ECDC4") {
                    ledger.colorHex = "#1C1C1E"
                }
            }
            try? context.save()
        }
    }

    /// Clears existing data and reseeds with fresh Malaysian Ringgit (MYR) defaults.
    static func resetToFreshMYRData(context: ModelContext) {
        // Delete existing ledgers, categories, tags, transactions, budgets, recurring, accounts
        try? context.delete(model: Transaction.self)
        try? context.delete(model: Budget.self)
        try? context.delete(model: RecurringRule.self)
        try? context.delete(model: Ledger.self)
        try? context.delete(model: Category.self)
        try? context.delete(model: Tag.self)
        try? context.delete(model: Account.self)
        try? context.save()

        UserDefaults.standard.set(true, forKey: "hasMigratedToMYR_v1_1")
        seedIfNeeded(context: context)
    }
}
