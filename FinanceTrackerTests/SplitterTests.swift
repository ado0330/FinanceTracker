import XCTest
import SwiftData
@testable import FinanceTracker

@MainActor
final class SplitterTests: XCTestCase {

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

    // MARK: - Math Expression Evaluator Tests

    func testMathExpressionEvaluatorSimple() {
        XCTAssertEqual(MathExpressionEvaluator.evaluate("10+5"), 15.0)
        XCTAssertEqual(MathExpressionEvaluator.evaluate("10 + 5"), 15.0)
        XCTAssertEqual(MathExpressionEvaluator.evaluate("100 / 4"), 25.0)
        XCTAssertEqual(MathExpressionEvaluator.evaluate("10 / 4"), 2.5) // Ensure float division
        XCTAssertEqual(MathExpressionEvaluator.evaluate("25.50 * 2"), 51.0)
        XCTAssertEqual(MathExpressionEvaluator.evaluate("50 - 12.50 + 5"), 42.5)
    }

    func testMathExpressionEvaluatorUnicodeOperators() {
        XCTAssertEqual(MathExpressionEvaluator.evaluate("20 × 3"), 60.0)
        XCTAssertEqual(MathExpressionEvaluator.evaluate("30 ÷ 2"), 15.0)
        XCTAssertEqual(MathExpressionEvaluator.evaluate("20 − 5"), 15.0)
    }

    func testMathExpressionEvaluatorEdgeCases() {
        // Trailing incomplete operator while typing
        XCTAssertEqual(MathExpressionEvaluator.evaluate("15 +"), 15.0)
        XCTAssertEqual(MathExpressionEvaluator.evaluate("20 * "), 20.0)

        // Invalid or division by zero
        XCTAssertNil(MathExpressionEvaluator.evaluate("10 / 0"))
        XCTAssertNil(MathExpressionEvaluator.evaluate("hello world"))
        XCTAssertNil(MathExpressionEvaluator.evaluate(""))
    }

    // MARK: - Debt Simplification Tests

    func testDebtSimplificationDirectTwoPeople() {
        let aliceID = UUID()
        let bobID = UUID()

        let summaries = [
            MemberBalanceSummary(id: aliceID, name: "Alice", icon: "person", colorHex: "#000", totalPaid: 100.0, totalOwed: 50.0), // net: +50
            MemberBalanceSummary(id: bobID, name: "Bob", icon: "person", colorHex: "#000", totalPaid: 0.0, totalOwed: 50.0)       // net: -50
        ]

        let transfers = DebtSimplifier.simplifyDebts(summaries: summaries)
        XCTAssertEqual(transfers.count, 1)
        XCTAssertEqual(transfers.first?.fromMemberID, bobID)
        XCTAssertEqual(transfers.first?.toMemberID, aliceID)
        XCTAssertEqual(transfers.first?.amount, 50.0)
    }

    func testDebtSimplificationThreePeopleMinimization() {
        // Alice paid 60 for (Alice 20, Bob 20, Charlie 20) -> Alice net +40, Bob net -20, Charlie net -20
        let a = UUID()
        let b = UUID()
        let c = UUID()

        let summaries = [
            MemberBalanceSummary(id: a, name: "Alice", icon: "person", colorHex: "#000", totalPaid: 60.0, totalOwed: 20.0), // +40
            MemberBalanceSummary(id: b, name: "Bob", icon: "person", colorHex: "#000", totalPaid: 0.0, totalOwed: 20.0),    // -20
            MemberBalanceSummary(id: c, name: "Charlie", icon: "person", colorHex: "#000", totalPaid: 0.0, totalOwed: 20.0) // -20
        ]

        let transfers = DebtSimplifier.simplifyDebts(summaries: summaries)
        XCTAssertEqual(transfers.count, 2)

        let totalTransferred = transfers.reduce(0.0) { $0 + $1.amount }
        XCTAssertEqual(totalTransferred, 40.0)
        XCTAssertTrue(transfers.allSatisfy { $0.toMemberID == a })
    }

    // MARK: - Receipt Parser Tests

    func testReceiptLineParsing() {
        let sampleLines = [
            "Welcome to Restoran Rasa",
            "Table 04  Cashier 1",
            "1x Nasi Lemak Ayam 15.90",
            "2 Teh Tarik 7.00",
            "Burger Deluxe 18.50",
            "Subtotal 41.40",
            "SST 6% 2.48",
            "Service Fee 4.14",
            "Total 48.02",
            "Thank you please come again"
        ]

        let result = ReceiptScannerService.parseReceiptLines(sampleLines)

        XCTAssertEqual(result.items.count, 3)
        XCTAssertEqual(result.items[0].name, "Nasi Lemak Ayam")
        XCTAssertEqual(result.items[0].quantity, 1)
        XCTAssertEqual(result.items[0].unitPrice, 15.90)

        XCTAssertEqual(result.items[1].name, "Teh Tarik")
        XCTAssertEqual(result.items[1].quantity, 2)
        XCTAssertEqual(result.items[1].unitPrice, 3.50) // 7.00 / 2

        XCTAssertEqual(result.tax, 2.48)
        XCTAssertEqual(result.serviceFee, 4.14)
        XCTAssertEqual(result.totalAmount, 48.02)
    }

    // MARK: - SwiftData Split Models Persistence Tests

    func testSplitExpensePersistence() {
        let ledger = Ledger(name: "Trip to Penang", currency: "MYR")
        context.insert(ledger)

        let member1 = SplitMember(name: "You", isCurrentUser: true, ledger: ledger)
        let member2 = SplitMember(name: "Alex", isCurrentUser: false, ledger: ledger)
        context.insert(member1)
        context.insert(member2)

        let expense = SplitExpense(
            title: "Dinner",
            totalAmount: 100.0,
            date: .now,
            splitMode: .equal,
            payers: [SplitPayer(memberID: member1.id, amount: 100.0)],
            shares: [
                SplitShare(memberID: member1.id, amount: 50.0),
                SplitShare(memberID: member2.id, amount: 50.0)
            ],
            ledger: ledger
        )
        context.insert(expense)
        try? context.save()

        XCTAssertEqual(expense.payers.count, 1)
        XCTAssertEqual(expense.shares.count, 2)
        XCTAssertEqual(expense.totalAmount, 100.0)
        XCTAssertFalse(expense.isSettled)
    }

    func testSplitGroupIsolationAndCascade() {
        let ledger = Ledger(name: "TestLedger", currency: "MYR")
        context.insert(ledger)

        let groupA = SplitGroup(name: "Penang Trip", icon: "airplane", colorHex: "#1C1C1E", ledger: ledger)
        let groupB = SplitGroup(name: "Roommates", icon: "house.fill", colorHex: "#5856D6", ledger: ledger)
        context.insert(groupA)
        context.insert(groupB)

        let memberA1 = SplitMember(name: "Alice", ledger: ledger, group: groupA)
        let memberA2 = SplitMember(name: "Bob", ledger: ledger, group: groupA)
        let memberB1 = SplitMember(name: "Charlie", ledger: ledger, group: groupB)
        context.insert(memberA1)
        context.insert(memberA2)
        context.insert(memberB1)

        let expenseA = SplitExpense(
            title: "Hotel",
            totalAmount: 300.0,
            date: .now,
            splitMode: .equal,
            payers: [SplitPayer(memberID: memberA1.id, amount: 300.0)],
            shares: [
                SplitShare(memberID: memberA1.id, amount: 150.0),
                SplitShare(memberID: memberA2.id, amount: 150.0)
            ],
            ledger: ledger,
            group: groupA
        )
        let expenseB = SplitExpense(
            title: "Electricity",
            totalAmount: 80.0,
            date: .now,
            splitMode: .equal,
            payers: [SplitPayer(memberID: memberB1.id, amount: 80.0)],
            shares: [SplitShare(memberID: memberB1.id, amount: 80.0)],
            ledger: ledger,
            group: groupB
        )
        context.insert(expenseA)
        context.insert(expenseB)
        try? context.save()

        // Verify group isolation
        XCTAssertEqual(groupA.expenses.count, 1)
        XCTAssertEqual(groupA.members.count, 2)
        XCTAssertEqual(groupA.unsettledTotal, 300.0)

        XCTAssertEqual(groupB.expenses.count, 1)
        XCTAssertEqual(groupB.members.count, 1)
        XCTAssertEqual(groupB.unsettledTotal, 80.0)
    }

    func testCrossGroupMemberProfileReuse() {
        let ledger = Ledger(name: "TestLedger", currency: "MYR")
        context.insert(ledger)

        let groupA = SplitGroup(name: "Penang Trip", icon: "airplane", colorHex: "#1C1C1E", ledger: ledger)
        context.insert(groupA)

        // Alex in group A has specific icon and color
        let alexInA = SplitMember(
            name: "Alex",
            icon: "sparkles",
            colorHex: "#AF52DE",
            isCurrentUser: false,
            ledger: ledger,
            group: groupA
        )
        let youInA = SplitMember(
            name: "You",
            icon: "person.fill",
            colorHex: "#1C1C1E",
            isCurrentUser: true,
            ledger: ledger,
            group: groupA
        )
        context.insert(alexInA)
        context.insert(youInA)
        try? context.save()

        // Verify unique friend profiles extracts Alex and excludes You/current user
        let allMembers = [alexInA, youInA]
        let friends = allMembers.uniqueFriendProfiles()
        XCTAssertEqual(friends.count, 1)
        XCTAssertEqual(friends.first?.name, "Alex")
        XCTAssertEqual(friends.first?.icon, "sparkles")
        XCTAssertEqual(friends.first?.colorHex, "#AF52DE")

        // When creating group B, Alex is reused with identical name, icon, and color
        let groupB = SplitGroup(name: "Roommates", icon: "house.fill", colorHex: "#007AFF", ledger: ledger)
        context.insert(groupB)

        let alexInB = SplitMember(
            name: alexInA.name,
            icon: alexInA.icon,
            colorHex: alexInA.colorHex,
            isCurrentUser: false,
            ledger: ledger,
            group: groupB
        )
        context.insert(alexInB)
        try? context.save()

        // Profiles match
        XCTAssertEqual(alexInB.name, "Alex")
        XCTAssertEqual(alexInB.icon, "sparkles")
        XCTAssertEqual(alexInB.colorHex, "#AF52DE")

        // Records remain cleanly isolated per group
        XCTAssertNotEqual(alexInA.id, alexInB.id)
        XCTAssertEqual(alexInA.group?.id, groupA.id)
        XCTAssertEqual(alexInB.group?.id, groupB.id)
    }

    func testUniqueFriendProfilesExclusion() {
        let member1 = SplitMember(name: "Alex", icon: "sparkles", colorHex: "#AF52DE", isCurrentUser: false)
        let member2 = SplitMember(name: "Bob", icon: "bolt.fill", colorHex: "#34C759", isCurrentUser: false)
        let member3 = SplitMember(name: "Charlie", icon: "star.fill", colorHex: "#FF9500", isCurrentUser: false)
        let currentUser = SplitMember(name: "You", isCurrentUser: true)

        let members = [member1, member2, member3, currentUser]

        // Exclude Alex who is already added
        let available = members.uniqueFriendProfiles(excludingNames: ["alex"])
        XCTAssertEqual(available.count, 2)
        XCTAssertTrue(available.contains { $0.name == "Bob" })
        XCTAssertTrue(available.contains { $0.name == "Charlie" })
        XCTAssertFalse(available.contains { $0.name == "Alex" })
    }

    // MARK: - Gemini Multimodal Receipt Parser Tests

    func testGeminiAPIResponseParsing() throws {
        let mockGeminiJSON = """
        {
          "candidates": [
            {
              "content": {
                "parts": [
                  {
                    "text": "{\\"items\\": [{\\"name\\": \\"Matcha Latte\\", \\"quantity\\": 2, \\"unitPrice\\": 14.00, \\"totalPrice\\": 28.00}, {\\"name\\": \\"Avocado Toast\\", \\"quantity\\": 1, \\"unitPrice\\": 24.50, \\"totalPrice\\": 24.50}], \\"tax\\": 3.15, \\"serviceFee\\": 5.25, \\"totalAmount\\": 60.90}"
                  }
                ]
              }
            }
          ]
        }
        """

        guard let data = mockGeminiJSON.data(using: .utf8) else {
            XCTFail("Failed to encode mock JSON")
            return
        }

        let result = try GeminiReceiptScannerService.parseGeminiAPIResponse(data)

        XCTAssertEqual(result.items.count, 2)
        XCTAssertEqual(result.items[0].name, "Matcha Latte")
        XCTAssertEqual(result.items[0].quantity, 2)
        XCTAssertEqual(result.items[0].unitPrice, 14.00)
        XCTAssertEqual(result.items[0].totalPrice, 28.00)

        XCTAssertEqual(result.items[1].name, "Avocado Toast")
        XCTAssertEqual(result.items[1].quantity, 1)
        XCTAssertEqual(result.items[1].unitPrice, 24.50)

        XCTAssertEqual(result.tax, 3.15)
        XCTAssertEqual(result.serviceFee, 5.25)
        XCTAssertEqual(result.totalAmount, 60.90)
    }

    func testGeminiMarkdownFenceParsing() throws {
        let mockFencedJSON = """
        {
          "candidates": [
            {
              "content": {
                "parts": [
                  {
                    "text": "```json\\n{\\"items\\": [{\\"name\\": \\"Burger\\", \\"quantity\\": 1, \\"unitPrice\\": 18.00}], \\"tax\\": 1.08, \\"serviceFee\\": 0.0, \\"totalAmount\\": 19.08}\\n```"
                  }
                ]
              }
            }
          ]
        }
        """

        guard let data = mockFencedJSON.data(using: .utf8) else {
            XCTFail("Failed to encode mock JSON")
            return
        }

        let result = try GeminiReceiptScannerService.parseGeminiAPIResponse(data)
        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.items[0].name, "Burger")
        XCTAssertEqual(result.totalAmount, 19.08)
    }

    func testGeminiAppSecretsAndDefaults() {
        XCTAssertTrue(GeminiReceiptScannerService.isAvailable)
        XCTAssertFalse(AppSecrets.geminiApiKey.isEmpty)
        XCTAssertEqual(AppSecrets.defaultGeminiModel, "gemini-3.5-flash-lite")
        XCTAssertEqual(GeminiReceiptScannerService.effectiveApiKey(userKey: nil), AppSecrets.geminiApiKey)
        XCTAssertEqual(GeminiReceiptScannerService.effectiveApiKey(userKey: "custom-key"), "custom-key")
        XCTAssertEqual(GeminiReceiptScannerService.effectiveModel(userModel: nil), "gemini-3.5-flash-lite")
        XCTAssertEqual(GeminiReceiptScannerService.effectiveModel(userModel: "gemini-2.5-flash"), "gemini-2.5-flash")
    }

    // MARK: - Malaysian 5-sen Rounding Tests

    func testMalaysianRoundingRules() {
        // Ending in 1, 2 sen -> round down to 0
        XCTAssertEqual(MalaysianRounding.roundToNearest5Sen(66.81), 66.80)
        XCTAssertEqual(MalaysianRounding.adjustment(for: 66.81), -0.01)
        XCTAssertEqual(MalaysianRounding.roundToNearest5Sen(66.82), 66.80)
        XCTAssertEqual(MalaysianRounding.adjustment(for: 66.82), -0.02)

        // Ending in 3, 4 sen -> round up to 5
        XCTAssertEqual(MalaysianRounding.roundToNearest5Sen(66.83), 66.85)
        XCTAssertEqual(MalaysianRounding.adjustment(for: 66.83), 0.02)
        XCTAssertEqual(MalaysianRounding.roundToNearest5Sen(66.84), 66.85)
        XCTAssertEqual(MalaysianRounding.adjustment(for: 66.84), 0.01)

        // Ending in 5 sen -> no adjustment
        XCTAssertEqual(MalaysianRounding.roundToNearest5Sen(66.85), 66.85)
        XCTAssertEqual(MalaysianRounding.adjustment(for: 66.85), 0.00)

        // Ending in 6, 7 sen -> round down to 5
        XCTAssertEqual(MalaysianRounding.roundToNearest5Sen(66.86), 66.85)
        XCTAssertEqual(MalaysianRounding.adjustment(for: 66.86), -0.01)
        XCTAssertEqual(MalaysianRounding.roundToNearest5Sen(66.87), 66.85)
        XCTAssertEqual(MalaysianRounding.adjustment(for: 66.87), -0.02)

        // Ending in 8, 9 sen -> round up to 10
        XCTAssertEqual(MalaysianRounding.roundToNearest5Sen(66.88), 66.90)
        XCTAssertEqual(MalaysianRounding.adjustment(for: 66.88), 0.02)
        XCTAssertEqual(MalaysianRounding.roundToNearest5Sen(66.89), 66.90)
        XCTAssertEqual(MalaysianRounding.adjustment(for: 66.89), 0.01)
    }

    func testGeminiReceiptParsingWithExplicitRounding() throws {
        let mockJSON = """
        {
          "candidates": [
            {
              "content": {
                "parts": [
                  {
                    "text": "{\\"items\\": [{\\"name\\": \\"Chicken Chop\\", \\"quantity\\": 2, \\"unitPrice\\": 31.52, \\"totalPrice\\": 63.04}], \\"tax\\": 3.78, \\"serviceFee\\": 0.0, \\"rounding\\": -0.02, \\"totalAmount\\": 66.80}"
                  }
                ]
              }
            }
          ]
        }
        """

        let data = try XCTUnwrap(mockJSON.data(using: .utf8))
        let result = try GeminiReceiptScannerService.parseGeminiAPIResponse(data)

        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.tax, 3.78)
        XCTAssertEqual(result.rounding, -0.02)
        XCTAssertEqual(result.totalAmount, 66.80)
    }

    func testGeminiReceiptParsingWithImplicitRoundingReconciliation() throws {
        // Pre-rounding sum = 63.04 + 3.78 = 66.82, but receipt totalAmount is 66.80
        let mockJSON = """
        {
          "candidates": [
            {
              "content": {
                "parts": [
                  {
                    "text": "{\\"items\\": [{\\"name\\": \\"Pasta\\", \\"quantity\\": 1, \\"unitPrice\\": 63.04, \\"totalPrice\\": 63.04}], \\"tax\\": 3.78, \\"serviceFee\\": 0.0, \\"totalAmount\\": 66.80}"
                  }
                ]
              }
            }
          ]
        }
        """

        let data = try XCTUnwrap(mockJSON.data(using: .utf8))
        let result = try GeminiReceiptScannerService.parseGeminiAPIResponse(data)

        XCTAssertEqual(result.rounding, -0.02)
        XCTAssertEqual(result.totalAmount, 66.80)
    }

    func testVisionOCRReceiptParsingWithRoundingLine() {
        let lines = [
            "Restoran Sedap",
            "Nasi Lemak Special 63.04",
            "SST 6% 3.78",
            "Rounding Adj -0.02",
            "Total 66.80"
        ]

        let result = ReceiptScannerService.parseReceiptLines(lines)
        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.tax, 3.78)
        XCTAssertEqual(result.rounding, -0.02)
        XCTAssertEqual(result.totalAmount, 66.80)
    }

    func testSplitExpenseRoundingPersistence() throws {
        let expense = SplitExpense(
            title: "Dinner with Rounding",
            totalAmount: 66.80,
            splitMode: .receipt,
            taxAmount: 3.78,
            serviceFeeAmount: 0.0,
            roundingAmount: -0.02
        )

        context.insert(expense)
        try context.save()

        let descriptor = FetchDescriptor<SplitExpense>()
        let fetched = try context.fetch(descriptor)
        let saved = try XCTUnwrap(fetched.first(where: { $0.id == expense.id }))

        XCTAssertEqual(saved.totalAmount, 66.80)
        XCTAssertEqual(saved.taxAmount, 3.78)
        XCTAssertEqual(saved.roundingAmount, -0.02)
    }

    // MARK: - Gemini Auto Bookkeeping for Back Tap Tests

    func testGeminiAutoBookkeepingParsing() throws {
        let mockJSON = """
        {
          "candidates": [
            {
              "content": {
                "parts": [
                  {
                    "text": "```json\\n{\\"merchant\\": \\"Starbucks Coffee\\", \\"totalAmount\\": 28.50, \\"date\\": \\"2026-10-04\\", \\"category\\": \\"Food & Dining\\", \\"items\\": [{\\"name\\": \\"Iced Latte\\", \\"quantity\\": 2, \\"unitPrice\\": 11.00, \\"totalPrice\\": 22.00}, {\\"name\\": \\"Croissant\\", \\"quantity\\": 1, \\"unitPrice\\": 6.50, \\"totalPrice\\": 6.50}], \\"tax\\": 1.70, \\"serviceFee\\": 0.0, \\"rounding\\": 0.0, \\"notes\\": \\"2x Iced Latte, 1x Croissant\\"}\\n```"
                  }
                ]
              }
            }
          ]
        }
        """

        let data = try XCTUnwrap(mockJSON.data(using: .utf8))
        let result = try GeminiReceiptScannerService.parseGeminiBookkeepingResponse(data)

        XCTAssertEqual(result.merchant, "Starbucks Coffee")
        XCTAssertEqual(result.totalAmount, 28.50)
        XCTAssertEqual(result.categoryName, "Food & Dining")
        XCTAssertEqual(result.items.count, 2)
        XCTAssertEqual(result.tax, 1.70)
        XCTAssertEqual(result.notes, "2x Iced Latte, 1x Croissant")
    }

    func testGeminiAutoBookkeepingImplicitRoundingReconciliation() throws {
        let mockJSON = """
        {
          "candidates": [
            {
              "content": {
                "parts": [
                  {
                    "text": "{\\"merchant\\": \\"FamilyMart\\", \\"totalAmount\\": 66.80, \\"date\\": \\"2026-10-04\\", \\"category\\": \\"Shopping\\", \\"items\\": [{\\"name\\": \\"Bento Box\\", \\"quantity\\": 2, \\"unitPrice\\": 31.52, \\"totalPrice\\": 63.04}], \\"tax\\": 3.78, \\"serviceFee\\": 0.0, \\"notes\\": \\"FamilyMart Bento\\"}"
                  }
                ]
              }
            }
          ]
        }
        """

        let data = try XCTUnwrap(mockJSON.data(using: .utf8))
        let result = try GeminiReceiptScannerService.parseGeminiBookkeepingResponse(data)

        XCTAssertEqual(result.merchant, "FamilyMart")
        XCTAssertEqual(result.rounding, -0.02)
        XCTAssertEqual(result.totalAmount, 66.80)
    }
}
