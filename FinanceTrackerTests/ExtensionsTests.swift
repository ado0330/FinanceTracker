import XCTest
import SwiftUI
@testable import FinanceTracker

final class ExtensionsTests: XCTestCase {

    func testColorHexRoundTrip() {
        let hex = "#FF6B6B"
        let color = Color(hex: hex)
        let generatedHex = color.hexString
        XCTAssertEqual(generatedHex.uppercased(), hex.uppercased())
    }

    func testDoubleCurrencyFormatting() {
        let amount = 1250.50
        let formattedMYR = amount.currencyString()
        XCTAssertTrue(formattedMYR.contains("RM") || formattedMYR.contains("MYR"))
        XCTAssertTrue(formattedMYR.contains("1,250.50") || formattedMYR.contains("1250.50"))

        let formatted = amount.currencyString(code: "USD")
        XCTAssertTrue(formatted.contains("1,250.50") || formatted.contains("1250.50"))

        let signedPos = amount.signedCurrencyString()
        XCTAssertTrue(signedPos.starts(with: "+"))

        let signedNeg = (-amount).signedCurrencyString()
        XCTAssertTrue(signedNeg.starts(with: "−") || signedNeg.starts(with: "-"))

        let compactK = 45_000.0.compactCurrencyString()
        XCTAssertTrue(compactK.contains("K"))

        let compactM = 2_500_000.0.compactCurrencyString()
        XCTAssertTrue(compactM.contains("M"))
    }

    func testDateHelpers() {
        let now = Date.now
        XCTAssertTrue(now.isSameMonth(as: now))
        XCTAssertTrue(now.isSameWeek(as: now))
        XCTAssertFalse(now.monthYearDisplay.isEmpty)
    }

    func testDaySectionDisplay() {
        let now = Date.now
        XCTAssertTrue(now.daySectionDisplay.starts(with: "Today ·"))

        let yesterday = now.adding(.day, value: -1)
        XCTAssertTrue(yesterday.daySectionDisplay.starts(with: "Yesterday ·"))

        let fiveDaysAgo = now.adding(.day, value: -5)
        XCTAssertFalse(fiveDaysAgo.daySectionDisplay.isEmpty)
        XCTAssertFalse(fiveDaysAgo.daySectionDisplay.starts(with: "Today"))
    }
}
