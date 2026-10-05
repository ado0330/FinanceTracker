import Foundation

/// Bank Negara Malaysia (BNM) 5-sen Rounding Mechanism Utility.
/// Under BNM guidelines for retail and cash transactions:
/// - 1, 2 sen -> round down to nearest 0 sen (e.g. 66.82 -> 66.80, adjustment -0.02)
/// - 3, 4 sen -> round up to nearest 5 sen (e.g. 66.83 -> 66.85, adjustment +0.02)
/// - 6, 7 sen -> round down to nearest 5 sen (e.g. 66.87 -> 66.85, adjustment -0.02)
/// - 8, 9 sen -> round up to nearest 10 sen (e.g. 66.88 -> 66.90, adjustment +0.02)
public enum MalaysianRounding {

    /// Rounds an amount to the nearest 5 sen (0.05).
    /// Examples:
    /// - 66.82 -> 66.80
    /// - 66.83 -> 66.85
    /// - 66.87 -> 66.85
    /// - 66.88 -> 66.90
    public static func roundToNearest5Sen(_ amount: Double) -> Double {
        return (amount * 20.0).rounded() / 20.0
    }

    /// Computes the rounding adjustment: rounded - raw.
    /// Examples:
    /// - 66.82 -> rounded 66.80 -> adjustment: -0.02
    /// - 66.83 -> rounded 66.85 -> adjustment: +0.02
    /// - 66.80 -> rounded 66.80 -> adjustment: 0.00
    public static func adjustment(for amount: Double) -> Double {
        let rounded = roundToNearest5Sen(amount)
        return ((rounded - amount) * 100.0).rounded() / 100.0
    }
}
