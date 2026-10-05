import Foundation
import SwiftData

/// A bank account, credit card, cash wallet, or e-wallet holding money or tracking liabilities.
@Model
final class Account {

    @Attribute(.unique) var id: UUID
    var name: String                // e.g. "Maybank Checking", "Chase Sapphire", "Daily Cash"
    var institution: String         // e.g. "Maybank", "CIMB", "Chase", "HSBC", "Cash"
    var accountTypeRaw: String      // AccountType.rawValue
    var accountNumberLast4: String  // e.g. "4821", optional
    var initialBalance: Double      // The initial starting balance
    var currency: String            // ISO 4217, e.g. "MYR", "USD"
    var colorHex: String            // Hex color code for card UI
    var icon: String                // SF Symbol
    var isArchived: Bool            // If hidden/closed
    var isDefault: Bool             // Default account for new transactions
    var note: String                // Optional user notes
    var createdAt: Date

    // MARK: - Relationships

    /// All transactions linked to this account.
    @Relationship(deleteRule: .nullify, inverse: \Transaction.account)
    var transactions: [Transaction] = []

    // MARK: - Init

    init(
        name: String,
        institution: String        = "",
        accountType: AccountType   = .bank,
        accountNumberLast4: String = "",
        initialBalance: Double     = 0.0,
        currency: String           = "MYR",
        colorHex: String           = "#1C1C1E",
        icon: String?              = nil,
        isArchived: Bool           = false,
        isDefault: Bool            = false,
        note: String               = ""
    ) {
        self.id                 = UUID()
        self.name               = name
        self.institution        = institution
        self.accountTypeRaw     = accountType.rawValue
        self.accountNumberLast4 = accountNumberLast4
        self.initialBalance     = initialBalance
        self.currency           = currency
        self.colorHex           = colorHex
        self.icon               = icon ?? accountType.defaultIcon
        self.isArchived         = isArchived
        self.isDefault          = isDefault
        self.note               = note
        self.createdAt          = .now
    }

    // MARK: - Computed Properties

    var accountType: AccountType {
        get { AccountType(rawValue: accountTypeRaw) ?? .bank }
        set { accountTypeRaw = newValue.rawValue }
    }

    var totalIncome: Double {
        transactions
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
    }

    var totalExpense: Double {
        transactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }

    /// Current balance accounting for initial balance and all linked transactions.
    /// For asset accounts (Bank, Savings, Cash, E-Wallet, Investment):
    ///   balance = initialBalance + totalIncome - totalExpense
    /// For credit cards:
    ///   balance = initialBalance + totalExpense - totalIncome (positive = outstanding debt owed)
    var currentBalance: Double {
        if accountType == .creditCard {
            return initialBalance + totalExpense - totalIncome
        } else {
            return initialBalance + totalIncome - totalExpense
        }
    }

    /// Full display title combining institution and account name
    var fullDisplayName: String {
        if institution.trimmingCharacters(in: .whitespaces).isEmpty {
            return name
        }
        return "\(institution) · \(name)"
    }

    /// Short masked number or badge (e.g. "•••• 4821")
    var maskedNumberDisplay: String {
        let trimmed = accountNumberLast4.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "" }
        return "•••• \(trimmed)"
    }

    /// Allows reconciling the account balance to a specified target amount (e.g. from bank statement).
    /// Adjusts initialBalance so currentBalance exactly matches the target.
    func reconcile(to newBalance: Double) {
        if accountType == .creditCard {
            initialBalance = newBalance - (totalExpense - totalIncome)
        } else {
            initialBalance = newBalance - (totalIncome - totalExpense)
        }
    }
}
