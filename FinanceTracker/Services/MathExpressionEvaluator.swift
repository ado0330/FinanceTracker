import Foundation

/// Evaluates simple mathematical expressions (e.g., "10 + 5", "100 / 4", "25.50 * 2", "50 - 12.50").
/// Safe against malformed inputs and division by zero.
enum MathExpressionEvaluator {

    /// Sanitizes and evaluates a string expression into a Double.
    /// Returns nil if the expression is invalid, empty, or cannot be evaluated.
    static func evaluate(_ rawInput: String) -> Double? {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // If it's already a clean number, parse directly
        if let directValue = Double(trimmed) {
            return directValue >= 0 ? directValue : nil
        }

        // Normalize operators
        var sanitized = trimmed
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: ",", with: ".")

        // Strip trailing incomplete operators while typing (e.g. "15+" -> "15")
        while sanitized.hasSuffix("+") || sanitized.hasSuffix("-") || sanitized.hasSuffix("*") || sanitized.hasSuffix("/") {
            sanitized.removeLast()
            sanitized = sanitized.trimmingCharacters(in: .whitespaces)
        }

        guard !sanitized.isEmpty else { return nil }

        // Whitelist allowed characters: digits, decimal point, basic arithmetic operators, parentheses, spaces
        let allowed = CharacterSet(charactersIn: "0123456789.+-*/() ")
        guard sanitized.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return nil
        }

        // Prevent division by zero pattern "/ 0" or "/0"
        let tokens = sanitized.components(separatedBy: CharacterSet.whitespaces).joined()
        if tokens.contains("/0") && !tokens.contains("/0.") {
            // Check if followed by non-zero digit
            if let range = tokens.range(of: "/0") {
                let suffix = tokens[range.upperBound...]
                if suffix.isEmpty || suffix.hasPrefix("+") || suffix.hasPrefix("-") || suffix.hasPrefix("*") || suffix.hasPrefix("/") || suffix.hasPrefix(")") {
                    return nil
                }
            }
        }

        // Use NSExpression with Double format for precision
        do {
            // Transform integer literals to double format (e.g. "10/4" -> "10.0/4.0") to avoid integer division truncation
            let doubleSanitized = promoteIntegersToDouble(sanitized)
            let expression = NSExpression(format: doubleSanitized)
            if let result = expression.expressionValue(with: nil, context: nil) as? NSNumber {
                let val = result.doubleValue
                if val.isFinite && !val.isNaN && val >= 0 {
                    return (val * 100).rounded() / 100.0 // Round to 2 decimal places
                }
            }
        } catch {
            return nil
        }

        return nil
    }

    /// Appends .0 to integer literals so NSExpression doesn't perform integer division (e.g. 10/4 = 2).
    private static func promoteIntegersToDouble(_ input: String) -> String {
        var result = ""
        var currentNumber = ""

        for char in input {
            if char.isNumber || char == "." {
                currentNumber.append(char)
            } else {
                if !currentNumber.isEmpty {
                    if !currentNumber.contains(".") {
                        currentNumber.append(".0")
                    }
                    result.append(currentNumber)
                    currentNumber = ""
                }
                result.append(char)
            }
        }

        if !currentNumber.isEmpty {
            if !currentNumber.contains(".") {
                currentNumber.append(".0")
            }
            result.append(currentNumber)
        }

        return result
    }
}
