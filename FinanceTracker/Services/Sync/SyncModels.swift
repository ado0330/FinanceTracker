import Foundation

/// Data Transfer Objects (DTOs) for mapping between SwiftData and Supabase PostgreSQL.
public struct LedgerDTO: Codable, Identifiable {
    public let id: UUID
    public let name: String
    public let currency: String
    public let color_hex: String
    public let is_default: Bool
    public let created_at: Date
    public let updated_at: Date
    public let deleted_at: Date?

    init(from ledger: Ledger, deletedAt: Date? = nil) {
        self.id = ledger.id
        self.name = ledger.name
        self.currency = ledger.currency
        self.color_hex = ledger.colorHex
        self.is_default = ledger.isDefault
        self.created_at = ledger.createdAt
        self.updated_at = .now
        self.deleted_at = deletedAt
    }
}

public struct CategoryDTO: Codable, Identifiable {
    public let id: UUID
    public let name: String
    public let icon: String
    public let color_hex: String
    public let type: String
    public let is_system: Bool
    public let sort_order: Int
    public let created_at: Date
    public let updated_at: Date
    public let deleted_at: Date?

    init(from category: Category, deletedAt: Date? = nil) {
        self.id = category.id
        self.name = category.name
        self.icon = category.icon
        self.color_hex = category.colorHex
        self.type = category.type.rawValue
        self.is_system = category.isSystem
        self.sort_order = category.sortOrder
        self.created_at = category.createdAt
        self.updated_at = .now
        self.deleted_at = deletedAt
    }
}

public struct AccountDTO: Codable, Identifiable {
    public let id: UUID
    public let name: String
    public let institution: String
    public let account_type: String
    public let last_four: String
    public let color_hex: String
    public let icon: String
    public let starting_balance: Double
    public let created_at: Date
    public let updated_at: Date
    public let deleted_at: Date?

    init(from account: Account, deletedAt: Date? = nil) {
        self.id = account.id
        self.name = account.name
        self.institution = account.institution
        self.account_type = account.accountTypeRaw
        self.last_four = account.accountNumberLast4
        self.color_hex = account.colorHex
        self.icon = account.icon
        self.starting_balance = account.initialBalance
        self.created_at = account.createdAt
        self.updated_at = .now
        self.deleted_at = deletedAt
    }
}

public struct TransactionDTO: Codable, Identifiable {
    public let id: UUID
    public let name: String?
    public let amount: Double
    public let type: String
    public let date: Date
    public let note: String
    public let receipt_image_base64: String?
    public let ledger_id: UUID?
    public let category_id: UUID?
    public let account_id: UUID?
    public let created_at: Date
    public let updated_at: Date
    public let deleted_at: Date?

    init(from transaction: Transaction, deletedAt: Date? = nil) {
        self.id = transaction.id
        self.name = transaction.name
        self.amount = transaction.amount
        self.type = transaction.type.rawValue
        self.date = transaction.date
        self.note = transaction.note
        self.receipt_image_base64 = transaction.receiptImageData?.base64EncodedString()
        self.ledger_id = transaction.ledger?.id
        self.category_id = transaction.category?.id
        self.account_id = transaction.account?.id
        self.created_at = transaction.createdAt
        self.updated_at = .now
        self.deleted_at = deletedAt
    }
}

public struct BudgetDTO: Codable, Identifiable {
    public let id: UUID
    public let amount: Double
    public let period: String
    public let alert_threshold: Double
    public let category_id: UUID?
    public let ledger_id: UUID?
    public let created_at: Date
    public let updated_at: Date
    public let deleted_at: Date?

    init(from budget: Budget, deletedAt: Date? = nil) {
        self.id = budget.id
        self.amount = budget.amount
        self.period = budget.period.rawValue
        self.alert_threshold = 0.8
        self.category_id = budget.category?.id
        self.ledger_id = budget.ledger?.id
        self.created_at = budget.createdAt
        self.updated_at = .now
        self.deleted_at = deletedAt
    }
}

public struct RecurringRuleDTO: Codable, Identifiable {
    public let id: UUID
    public let amount: Double
    public let type: String
    public let note: String
    public let frequency: String
    public let interval_value: Int
    public let next_due_date: Date
    public let is_active: Bool
    public let category_id: UUID?
    public let ledger_id: UUID?
    public let created_at: Date
    public let updated_at: Date
    public let deleted_at: Date?

    init(from rule: RecurringRule, deletedAt: Date? = nil) {
        self.id = rule.id
        self.amount = rule.amount
        self.type = rule.type.rawValue
        self.note = rule.note
        self.frequency = rule.frequency.rawValue
        self.interval_value = 1
        self.next_due_date = rule.nextDueDate
        self.is_active = rule.isActive
        self.category_id = rule.category?.id
        self.ledger_id = rule.ledger?.id
        self.created_at = rule.createdAt
        self.updated_at = .now
        self.deleted_at = deletedAt
    }
}

public struct TagDTO: Codable, Identifiable {
    public let id: UUID
    public let name: String
    public let color_hex: String
    public let created_at: Date
    public let updated_at: Date
    public let deleted_at: Date?

    init(from tag: Tag, deletedAt: Date? = nil) {
        self.id = tag.id
        self.name = tag.name
        self.color_hex = tag.colorHex
        self.created_at = tag.createdAt
        self.updated_at = .now
        self.deleted_at = deletedAt
    }
}
