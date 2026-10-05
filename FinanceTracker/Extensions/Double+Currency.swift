import Foundation

// MARK: - Module-level formatter cache
//
// NumberFormatter is expensive to instantiate (~0.5 ms). We cache one instance
// per currency code so repeated calls (e.g. in a list of 500 rows) stay fast.

private var _formatterCache: [String: NumberFormatter] = [:]

private func cachedFormatter(currencyCode: String) -> NumberFormatter {
    if let cached = _formatterCache[currencyCode] { return cached }
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = currencyCode
    if currencyCode == "MYR" {
        f.locale = Locale(identifier: "en_MY")
    }
    f.minimumFractionDigits = 2
    f.maximumFractionDigits = 2
    _formatterCache[currencyCode] = f
    return f
}

// MARK: - Double + Currency Formatting

extension Double {

    // MARK: Full Precision

    /// Formats as a full currency string using the supplied ISO 4217 code.
    ///
    ///     1234.5.currencyString(code: "MYR")  →  "RM1,234.50"
    func currencyString(code: String = "MYR") -> String {
        cachedFormatter(currencyCode: code)
            .string(from: NSNumber(value: self))
            ?? "\(code) \(self)"
    }

    /// Formats with an explicit `+` / `−` sign prefix.
    ///
    ///     1500.0.signedCurrencyString(code: "MYR")   →  "+RM1,500.00"
    ///     -200.0.signedCurrencyString(code: "MYR")   →  "−RM200.00"
    func signedCurrencyString(code: String = "MYR") -> String {
        let base = Swift.abs(self).currencyString(code: code)
        return self >= 0 ? "+\(base)" : "−\(base)"
    }

    // MARK: Compact (Chart Labels)

    /// Abbreviates large values to keep chart axis labels readable.
    ///
    ///     1_200_000.compactCurrencyString(code: "MYR")  →  "RM1.2M"
    ///     85_300.compactCurrencyString(code: "MYR")     →  "RM85.3K"
    ///     340.compactCurrencyString(code: "MYR")        →  "RM340.00"
    func compactCurrencyString(code: String = "MYR") -> String {
        let absValue = Swift.abs(self)

        let compact = NumberFormatter()
        compact.numberStyle = .currency
        compact.currencyCode = code
        if code == "MYR" {
            compact.locale = Locale(identifier: "en_MY")
        }
        compact.maximumFractionDigits = 1
        compact.minimumFractionDigits = 0

        switch absValue {
        case 1_000_000...:
            return (compact.string(from: NSNumber(value: self / 1_000_000)) ?? "") + "M"
        case 1_000...:
            return (compact.string(from: NSNumber(value: self / 1_000)) ?? "") + "K"
        default:
            compact.maximumFractionDigits = 2
            return compact.string(from: NSNumber(value: self)) ?? "\(self)"
        }
    }

    // MARK: Percentage

    /// Formats 0.0…1.0 as a percentage string.
    ///
    ///     0.742.percentageString  →  "74%"
    var percentageString: String {
        let pct = Int((self * 100).rounded())
        return "\(pct)%"
    }
}
