import Foundation
import SwiftData
@testable import FinanceTracker

/// Disambiguate with Objective-C Category
typealias Category = FinanceTracker.Category

@MainActor
struct TestModelContainer {
    static func create() throws -> ModelContainer {
        let schema = Schema([
            Ledger.self,
            Transaction.self,
            Category.self,
            Tag.self,
            Budget.self,
            RecurringRule.self,
            SplitMember.self,
            SplitExpense.self,
            SplitSettlement.self,
            SplitGroup.self,
            Account.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
