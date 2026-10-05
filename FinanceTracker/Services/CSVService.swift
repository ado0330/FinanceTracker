import Foundation
import SwiftData

/// Handles CSV export and import for transactions.
final class CSVService {
    private init() {}

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()

    // MARK: - Export

    /// Exports an array of transactions to an RFC 4180 compliant CSV string.
    ///
    /// Header: Date,Type,Category,Amount,Note,Tags,RecurringRuleID
    static func exportCSV(transactions: [Transaction], currencyCode: String = "") -> String {
        var lines: [String] = []
        lines.append("Date,Type,Category,Amount,Note,Tags,RecurringRuleID")

        let sorted = transactions.sorted { $0.date > $1.date }

        for tx in sorted {
            let dateStr = dateFormatter.string(from: tx.date)
            let typeStr = tx.type.rawValue
            let categoryStr = escape(tx.category?.name ?? "")
            let amountStr = String(format: "%.2f", tx.amount)
            let noteStr = escape(tx.note)
            let tagsStr = escape(tx.tags.map(\.name).sorted().joined(separator: ";"))
            let ruleStr = tx.recurringRuleID?.uuidString ?? ""

            let row = "\(dateStr),\(typeStr),\(categoryStr),\(amountStr),\(noteStr),\(tagsStr),\(ruleStr)"
            lines.append(row)
        }

        return lines.joined(separator: "\n")
    }

    /// Creates a temporary .csv file in the cache/temp directory for sharing via ShareLink.
    static func createTempCSVFile(from csvString: String, filename: String = "FinanceTracker_Export.csv") -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
    }

    // MARK: - Import

    /// Imports transactions from a CSV string into the specified ledger and ModelContext.
    ///
    /// Returns the number of successfully imported transactions and a list of per-row error descriptions.
    static func importCSV(
        from string: String,
        ledger: Ledger,
        context: ModelContext
    ) -> (imported: Int, errors: [String]) {
        let rows = parseCSV(string)
        guard let headerRow = rows.first else {
            return (0, ["The CSV file is empty."])
        }

        // Identify column indices from header
        var dateIdx: Int?
        var typeIdx: Int?
        var categoryIdx: Int?
        var amountIdx: Int?
        var noteIdx: Int?
        var tagsIdx: Int?
        var ruleIdx: Int?

        for (index, col) in headerRow.enumerated() {
            let clean = col.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if clean == "date" { dateIdx = index }
            else if clean == "type" { typeIdx = index }
            else if clean == "category" { categoryIdx = index }
            else if clean == "amount" { amountIdx = index }
            else if clean == "note" || clean == "notes" || clean == "memo" || clean == "description" { noteIdx = index }
            else if clean == "tags" || clean == "tag" { tagsIdx = index }
            else if clean.contains("recurring") { ruleIdx = index }
        }

        // Positional fallback if headers are not explicitly named
        if dateIdx == nil && typeIdx == nil && amountIdx == nil && headerRow.count >= 4 {
            dateIdx = 0
            typeIdx = 1
            categoryIdx = 2
            amountIdx = 3
            noteIdx = headerRow.count > 4 ? 4 : nil
            tagsIdx = headerRow.count > 5 ? 5 : nil
            ruleIdx = headerRow.count > 6 ? 6 : nil
        }

        guard let resolvedDateIdx = dateIdx,
              let resolvedTypeIdx = typeIdx,
              let resolvedAmountIdx = amountIdx else {
            return (0, ["Missing required CSV columns. Required: Date, Type, Amount."])
        }

        // Fetch existing categories to resolve relationships
        let catDescriptor = FetchDescriptor<Category>()
        let existingCategories = (try? context.fetch(catDescriptor)) ?? []
        var categoryMap: [String: Category] = [:]
        for cat in existingCategories {
            categoryMap[cat.name.lowercased()] = cat
        }

        // Fetch existing tags to resolve relationships
        let tagDescriptor = FetchDescriptor<Tag>()
        let existingTags = (try? context.fetch(tagDescriptor)) ?? []
        var tagMap: [String: Tag] = [:]
        for tag in existingTags {
            tagMap[tag.name.lowercased()] = tag
        }

        var importedCount = 0
        var errors: [String] = []

        // Process data rows (skip header)
        for (rowIndex, row) in rows.dropFirst().enumerated() {
            let lineNumber = rowIndex + 2

            // Validate date
            guard resolvedDateIdx < row.count else {
                errors.append("Row \(lineNumber): Missing date column.")
                continue
            }
            let rawDate = row[resolvedDateIdx]
            guard let date = parseDate(rawDate) else {
                errors.append("Row \(lineNumber): Unrecognized date format '\(rawDate)'.")
                continue
            }

            // Validate type
            guard resolvedTypeIdx < row.count else {
                errors.append("Row \(lineNumber): Missing type column.")
                continue
            }
            let rawType = row[resolvedTypeIdx].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let txType: TransactionType
            if rawType == "income" || rawType == "+" {
                txType = .income
            } else if rawType == "expense" || rawType == "-" || rawType == "−" {
                txType = .expense
            } else {
                errors.append("Row \(lineNumber): Invalid transaction type '\(row[resolvedTypeIdx])'. Must be 'income' or 'expense'.")
                continue
            }

            // Validate amount
            guard resolvedAmountIdx < row.count else {
                errors.append("Row \(lineNumber): Missing amount column.")
                continue
            }
            let cleanAmount = row[resolvedAmountIdx]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "$", with: "")
                .replacingOccurrences(of: "€", with: "")
                .replacingOccurrences(of: "£", with: "")
                .replacingOccurrences(of: "¥", with: "")
                .replacingOccurrences(of: ",", with: "")

            guard let amount = Double(cleanAmount), amount >= 0 else {
                errors.append("Row \(lineNumber): Invalid amount value '\(row[resolvedAmountIdx])'.")
                continue
            }

            // Match or create category
            var category: Category? = nil
            if let catIdx = categoryIdx, catIdx < row.count {
                let catName = row[catIdx].trimmingCharacters(in: .whitespacesAndNewlines)
                if !catName.isEmpty {
                    if let existing = categoryMap[catName.lowercased()] {
                        category = existing
                    } else {
                        let newCat = Category(
                            name: catName,
                            icon: txType == .income ? "arrow.up.circle" : "cart.fill",
                            colorHex: "#5A8BDF",
                            type: txType == .income ? .income : .expense
                        )
                        context.insert(newCat)
                        categoryMap[catName.lowercased()] = newCat
                        category = newCat
                    }
                }
            }

            // Note
            var note = ""
            if let noteIdx = noteIdx, noteIdx < row.count {
                note = row[noteIdx]
            }

            // Tags
            var txTags: [Tag] = []
            if let tagsIdx = tagsIdx, tagsIdx < row.count {
                let rawTags = row[tagsIdx].trimmingCharacters(in: .whitespacesAndNewlines)
                if !rawTags.isEmpty {
                    let separator: Character = rawTags.contains(";") ? ";" : ","
                    let tagNames = rawTags.split(separator: separator)
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }

                    for name in tagNames {
                        if let existing = tagMap[name.lowercased()] {
                            txTags.append(existing)
                        } else {
                            let newTag = Tag(name: name)
                            context.insert(newTag)
                            tagMap[name.lowercased()] = newTag
                            txTags.append(newTag)
                        }
                    }
                }
            }

            // Recurring rule ID
            var recurringRuleID: UUID? = nil
            if let ruleIdx = ruleIdx, ruleIdx < row.count {
                let rawRule = row[ruleIdx].trimmingCharacters(in: .whitespacesAndNewlines)
                if !rawRule.isEmpty {
                    recurringRuleID = UUID(uuidString: rawRule)
                }
            }

            // Insert transaction
            let transaction = Transaction(
                name: !note.isEmpty ? note : (category?.name ?? "Imported Transaction"),
                amount: amount,
                type: txType,
                date: date,
                note: note,
                ledger: ledger,
                category: category,
                tags: txTags,
                recurringRuleID: recurringRuleID
            )
            context.insert(transaction)
            importedCount += 1
        }

        try? context.save()
        return (imported: importedCount, errors: errors)
    }

    // MARK: - CSV Parsing & Escaping Helpers

    /// Parses a CSV string into a 2D array of rows and columns complying with RFC 4180.
    static func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false

        var iterator = text.makeIterator()
        var peekChar: Character? = iterator.next()

        while let char = peekChar {
            let nextChar = iterator.next()

            if inQuotes {
                if char == "\"" {
                    if nextChar == "\"" {
                        // Escaped quote
                        currentField.append("\"")
                        peekChar = iterator.next()
                        continue
                    } else {
                        // End of quote
                        inQuotes = false
                    }
                } else {
                    currentField.append(char)
                }
            } else {
                if char == "\"" {
                    inQuotes = true
                } else if char == "," {
                    currentRow.append(currentField.trimmingCharacters(in: .whitespaces))
                    currentField = ""
                } else if char == "\r" {
                    if nextChar == "\n" {
                        currentRow.append(currentField.trimmingCharacters(in: .whitespaces))
                        currentField = ""
                        rows.append(currentRow)
                        currentRow = []
                        peekChar = iterator.next()
                        continue
                    } else {
                        currentRow.append(currentField.trimmingCharacters(in: .whitespaces))
                        currentField = ""
                        rows.append(currentRow)
                        currentRow = []
                    }
                } else if char == "\n" {
                    currentRow.append(currentField.trimmingCharacters(in: .whitespaces))
                    currentField = ""
                    rows.append(currentRow)
                    currentRow = []
                } else {
                    currentField.append(char)
                }
            }

            peekChar = nextChar
        }

        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField.trimmingCharacters(in: .whitespaces))
            rows.append(currentRow)
        }

        return rows.filter { row in
            row.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
    }

    /// Flexible date parser supporting standard format, ISO-8601, and date-only formats.
    private static func parseDate(_ dateStr: String) -> Date? {
        let trimmed = dateStr.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. "yyyy-MM-dd HH:mm:ss"
        if let date = dateFormatter.date(from: trimmed) {
            return date
        }

        // 2. ISO 8601 with fractional seconds
        let isoFractional = ISO8601DateFormatter()
        isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFractional.date(from: trimmed) {
            return date
        }

        // 3. ISO 8601 standard
        let isoStandard = ISO8601DateFormatter()
        isoStandard.formatOptions = [.withInternetDateTime]
        if let date = isoStandard.date(from: trimmed) {
            return date
        }

        // 4. "yyyy-MM-dd"
        let dfYMD = DateFormatter()
        dfYMD.dateFormat = "yyyy-MM-dd"
        dfYMD.locale = Locale(identifier: "en_US_POSIX")
        if let date = dfYMD.date(from: trimmed) {
            return date
        }

        // 5. "MM/dd/yyyy"
        let dfMDY = DateFormatter()
        dfMDY.dateFormat = "MM/dd/yyyy"
        dfMDY.locale = Locale(identifier: "en_US_POSIX")
        if let date = dfMDY.date(from: trimmed) {
            return date
        }

        // 6. "dd/MM/yyyy"
        let dfDMY = DateFormatter()
        dfDMY.dateFormat = "dd/MM/yyyy"
        dfDMY.locale = Locale(identifier: "en_US_POSIX")
        if let date = dfDMY.date(from: trimmed) {
            return date
        }

        return nil
    }

    /// Escapes a CSV field according to RFC 4180 rules.
    static func escape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
}
