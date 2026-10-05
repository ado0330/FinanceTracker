import SwiftUI

/// Executive summary card that provides an overall conclusion for a specific selected month.
///
/// Displays:
/// - Total spent, total income, net cash flow
/// - Plain-English comparative conclusion vs preceding month
/// - Top spending category highlight
/// - Direct "View All Transactions" launcher button
struct MonthConclusionCard: View {

    let selectedDate: Date
    let transactions: [Transaction]
    let currencyCode: String
    let onViewTransactions: () -> Void

    // MARK: - Calculations

    private var monthStart: Date { selectedDate.startOfMonth }
    private var monthEnd: Date { selectedDate.endOfMonth }

    private var monthTransactions: [Transaction] {
        transactions.filter { $0.date >= monthStart && $0.date <= monthEnd }
    }

    private var monthExpenseTransactions: [Transaction] {
        monthTransactions.filter { $0.type == .expense }
    }

    private var monthIncomeTransactions: [Transaction] {
        monthTransactions.filter { $0.type == .income }
    }

    private var totalExpense: Double {
        monthExpenseTransactions.reduce(0) { $0 + $1.amount }
    }

    private var totalIncome: Double {
        monthIncomeTransactions.reduce(0) { $0 + $1.amount }
    }

    private var netSavings: Double {
        totalIncome - totalExpense
    }

    // Previous month comparison
    private var prevMonthStart: Date { selectedDate.adding(.month, value: -1).startOfMonth }
    private var prevMonthEnd: Date { selectedDate.adding(.month, value: -1).endOfMonth }

    private var prevExpense: Double {
        transactions.filter {
            $0.type == .expense && $0.date >= prevMonthStart && $0.date <= prevMonthEnd
        }.reduce(0) { $0 + $1.amount }
    }

    private var expenseDiff: Double {
        totalExpense - prevExpense
    }

    private var pctChange: Double? {
        guard prevExpense > 0 else { return nil }
        return ((totalExpense - prevExpense) / prevExpense) * 100.0
    }

    // Top Category
    private struct TopCategoryInfo {
        let name: String
        let icon: String
        let colorHex: String
        let amount: Double
        let percentage: Double
    }

    private var topCategory: TopCategoryInfo? {
        guard totalExpense > 0 else { return nil }
        var map: [String: (icon: String, hex: String, amount: Double)] = [:]
        for txn in monthExpenseTransactions {
            let name = txn.category?.name ?? "Other"
            let icon = txn.category?.icon ?? "folder"
            let hex = txn.category?.colorHex ?? "#1C1C1E"
            let existing = map[name] ?? (icon: icon, hex: hex, amount: 0.0)
            map[name] = (icon: icon, hex: hex, amount: existing.amount + txn.amount)
        }

        guard let top = map.max(by: { $0.value.amount < $1.value.amount }) else { return nil }
        return TopCategoryInfo(
            name: top.key,
            icon: top.value.icon,
            colorHex: top.value.hex,
            amount: top.value.amount,
            percentage: (top.value.amount / totalExpense) * 100.0
        )
    }

    // Conclusion Narrative
    private var narrativeConclusion: String {
        let monthName = selectedDate.shortMonthString
        let prevMonthName = selectedDate.adding(.month, value: -1).shortMonthString

        if totalExpense == 0 && totalIncome == 0 {
            return "No financial records found for \(monthName) \(Calendar.current.component(.year, from: selectedDate))."
        }

        var sentences: [String] = []

        if prevExpense > 0 {
            let isSaved = expenseDiff < 0
            let diffFormatted = Swift.abs(expenseDiff).currencyString(code: currencyCode)
            let pctFormatted = String(format: "%.1f%%", Swift.abs(pctChange ?? 0))
            if isSaved {
                sentences.append("In \(monthName), you spent \(totalExpense.currencyString(code: currencyCode)) — saving \(diffFormatted) (-\(pctFormatted)) compared to \(prevMonthName).")
            } else {
                sentences.append("In \(monthName), you spent \(totalExpense.currencyString(code: currencyCode)) — \(diffFormatted) (+\(pctFormatted)) more than \(prevMonthName).")
            }
        } else {
            sentences.append("Total expenditure was \(totalExpense.currencyString(code: currencyCode)).")
        }

        if let top = topCategory {
            sentences.append("Your highest spending category was \(top.name) at \(top.amount.currencyString(code: currencyCode)) (\(String(format: "%.0f%%", top.percentage)) of total).")
        }

        return sentences.joined(separator: " ")
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Header: Month Title & Conclusion Tag
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MONTH OVERVIEW · \(selectedDate.shortMonthString.uppercased())")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .tracking(1)

                    Text(selectedDate.monthYearString)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                }

                Spacer()

                if prevExpense > 0 {
                    let isSaved = expenseDiff < 0
                    HStack(spacing: 4) {
                        Image(systemName: isSaved ? "arrow.down.right" : "arrow.up.right")
                        Text(String(format: "%@%.1f%% vs prev", expenseDiff >= 0 ? "+" : "", pctChange ?? 0))
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isSaved ? .green : .primary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(isSaved ? Color.green.opacity(0.12) : Color.primary.opacity(0.08))
                    .clipShape(Capsule())
                }
            }

            // Metric Summary 3-Box Row
            HStack(spacing: 10) {
                metricBox(
                    label: "Spent",
                    amount: totalExpense,
                    color: .primary
                )

                metricBox(
                    label: "Income",
                    amount: totalIncome,
                    color: .green
                )

                metricBox(
                    label: "Net Savings",
                    amount: netSavings,
                    color: netSavings >= 0 ? Color.primary : Color.red
                )
            }

            // Plain-English Conclusion
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .padding(.top, 2)

                Text(narrativeConclusion)
                    .font(.subheadline)
                    .foregroundStyle(.primary.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Action: View All Transactions
            Button {
                onViewTransactions()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet.rectangle.portrait")
                        .font(.subheadline.bold())
                    Text("View All \(monthTransactions.count) Transactions")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                }
                .foregroundStyle(Color(uiColor: .systemBackground))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.top, 2)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Metric Box

    private func metricBox(label: String, amount: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(amount.compactCurrencyString(code: currencyCode))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
