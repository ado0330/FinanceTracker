import Foundation

// MARK: - Transaction Type

enum TransactionType: String, Codable, CaseIterable, Identifiable {
    case income  = "income"
    case expense = "expense"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .income:  return "Income"
        case .expense: return "Expense"
        }
    }

    var sign: String {
        switch self {
        case .income:  return "+"
        case .expense: return "−"
        }
    }

    var systemImage: String {
        switch self {
        case .income:  return "arrow.up.circle.fill"
        case .expense: return "arrow.down.circle.fill"
        }
    }
}

// MARK: - Category Type

enum CategoryType: String, Codable, CaseIterable, Identifiable {
    case income  = "income"
    case expense = "expense"
    case both    = "both"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .income:  return "Income"
        case .expense: return "Expense"
        case .both:    return "Both"
        }
    }
}

// MARK: - Budget Period

enum BudgetPeriod: String, Codable, CaseIterable, Identifiable {
    case weekly  = "weekly"
    case monthly = "monthly"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weekly:  return "Weekly"
        case .monthly: return "Monthly"
        }
    }
}

// MARK: - Recurring Frequency

enum RecurringFrequency: String, Codable, CaseIterable, Identifiable {
    case daily     = "daily"
    case weekly    = "weekly"
    case biweekly  = "biweekly"
    case monthly   = "monthly"
    case quarterly = "quarterly"
    case yearly    = "yearly"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily:     return "Daily"
        case .weekly:    return "Weekly"
        case .biweekly:  return "Every 2 Weeks"
        case .monthly:   return "Monthly"
        case .quarterly: return "Every 3 Months"
        case .yearly:    return "Yearly"
        }
    }

    /// Calendar component + value used to advance `nextDueDate` by one period.
    var calendarAdvance: (component: Calendar.Component, value: Int) {
        switch self {
        case .daily:     return (.day, 1)
        case .weekly:    return (.weekOfYear, 1)
        case .biweekly:  return (.weekOfYear, 2)
        case .monthly:   return (.month, 1)
        case .quarterly: return (.month, 3)
        case .yearly:    return (.year, 1)
        }
    }
}

// MARK: - Summary Period (shared by DashboardView and ChartsView)

enum SummaryPeriod: String, CaseIterable, Identifiable {
    case monthly = "Monthly"
    case weekly  = "Weekly"

    var id: String { rawValue }
}

// MARK: - Account Type

enum AccountType: String, Codable, CaseIterable, Identifiable {
    case bank       = "bank"        // Bank Checking / Current Account
    case savings    = "savings"     // Savings Account / High Yield / Fixed Deposit
    case creditCard = "creditCard"  // Credit Card / Line of Credit
    case cash       = "cash"        // Physical Cash / Pocket Wallet
    case eWallet    = "eWallet"     // E-Wallet (Touch 'n Go, GrabPay, Apple Cash, PayPal)
    case investment = "investment"  // Investment / Brokerage / Crypto

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bank:       return "Bank Account"
        case .savings:    return "Savings"
        case .creditCard: return "Credit Card"
        case .cash:       return "Cash / Wallet"
        case .eWallet:    return "E-Wallet"
        case .investment: return "Investment"
        }
    }

    var defaultIcon: String {
        switch self {
        case .bank:       return "building.columns.fill"
        case .savings:    return "leaf.fill"
        case .creditCard: return "creditcard.fill"
        case .cash:       return "banknote.fill"
        case .eWallet:    return "wallet.pass.fill"
        case .investment: return "chart.line.uptrend.xyaxis"
        }
    }

    /// Whether this account type represents an asset (positive value counts towards net worth)
    /// vs liability (credit card debt).
    var isAsset: Bool {
        self != .creditCard
    }
}
