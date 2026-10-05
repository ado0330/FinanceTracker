import SwiftUI

/// Detailed modal sheet displaying a single month's total expenditure, income,
/// category distribution, daily average, and month-over-month comparison.
struct MonthBreakdownSheet: View {

    let monthTitle: String
    let monthDate: Date
    let transactions: [Transaction]
    let previousMonthTransactions: [Transaction]
    let currencyCode: String

    @Environment(\.dismiss) private var dismiss

    @State private var editingTransaction: Transaction? = nil
    @State private var showEditSheet: Bool = false

    // MARK: - Computed Metrics

    private var expenseTransactions: [Transaction] {
        transactions.filter { $0.type == .expense }
    }

    private var incomeTransactions: [Transaction] {
        transactions.filter { $0.type == .income }
    }

    private var totalExpense: Double {
        expenseTransactions.reduce(0) { $0 + $1.amount }
    }

    private var totalIncome: Double {
        incomeTransactions.reduce(0) { $0 + $1.amount }
    }

    private var netSavings: Double {
        totalIncome - totalExpense
    }

    private var previousExpense: Double {
        previousMonthTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    private var expenseDiff: Double {
        totalExpense - previousExpense
    }

    private var percentageChange: Double? {
        guard previousExpense > 0 else { return nil }
        return ((totalExpense - previousExpense) / previousExpense) * 100.0
    }

    private var daysInMonth: Int {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: monthDate)
        return range?.count ?? 30
    }

    private var dailyAverage: Double {
        guard daysInMonth > 0 else { return 0 }
        return totalExpense / Double(daysInMonth)
    }

    // Category breakdown
    struct CategoryBreakdownItem: Identifiable {
        let id: String
        let name: String
        let icon: String
        let colorHex: String
        let amount: Double
        let percentage: Double
        let count: Int
    }

    private var categoryBreakdown: [CategoryBreakdownItem] {
        guard totalExpense > 0 else { return [] }
        let grouped = Dictionary(grouping: expenseTransactions) { $0.category?.name ?? "Uncategorised" }

        return grouped.map { name, items in
            let amount = items.reduce(0) { $0 + $1.amount }
            let first = items.first?.category
            return CategoryBreakdownItem(
                id: name,
                name: name,
                icon: first?.icon ?? "folder",
                colorHex: first?.colorHex ?? "#1C1C1E",
                amount: amount,
                percentage: (amount / totalExpense) * 100.0,
                count: items.count
            )
        }
        .sorted { $0.amount > $1.amount }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // 1. Hero Month Total Card
                    heroCard

                    // 2. MoM Comparison Callout
                    comparisonCallout

                    // 3. Category Breakdown Section
                    categorySection

                    // 4. Quick Stats Section
                    quickStatsSection

                    // 5. Month Transactions Section
                    transactionsSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("\(monthTitle) Breakdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                }
            }
            .sheet(isPresented: $showEditSheet) {
                AddEditTransactionView(transaction: $editingTransaction) {
                    showEditSheet = false
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Subviews

    private var heroCard: some View {
        VStack(spacing: 12) {
            Text("TOTAL EXPENSE")
                .font(.caption2.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(.secondary)

            Text(totalExpense.currencyString(code: currencyCode))
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(.green)
                    Text("Income: \(totalIncome.currencyString(code: currencyCode))")
                        .font(.caption.weight(.medium))
                }

                HStack(spacing: 4) {
                    Image(systemName: "equal.circle.fill")
                        .foregroundStyle(netSavings >= 0 ? Color.primary : Color.red)
                    Text("Net: \(netSavings.signedCurrencyString(code: currencyCode))")
                        .font(.caption.weight(.medium))
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var comparisonCallout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Month-over-Month Comparison", systemImage: "arrow.left.arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
            }

            if previousExpense > 0 {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(expenseDiff >= 0 ? "Spent More" : "Saved More")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(expenseDiff <= 0 ? .green : .primary)

                        Text(comparisonText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: expenseDiff <= 0 ? "arrow.down.right" : "arrow.up.right")
                        Text(String(format: "%@%.1f%%", expenseDiff >= 0 ? "+" : "", percentageChange ?? 0))
                            .font(.subheadline.weight(.bold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(Capsule())
                }
            } else {
                Text("No previous month data available to compare.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var comparisonText: String {
        let diffFormatted = Swift.abs(expenseDiff).currencyString(code: currencyCode)
        let prevFormatted = previousExpense.currencyString(code: currencyCode)
        if expenseDiff < 0 {
            return "Saved \(diffFormatted) compared to previous month (\(prevFormatted))."
        } else if expenseDiff > 0 {
            return "Spent \(diffFormatted) more than previous month (\(prevFormatted))."
        } else {
            return "Spending was identical to previous month (\(prevFormatted))."
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Category Spending Breakdown")
                    .font(.headline)
                Spacer()
                Text("\(categoryBreakdown.count) Categories")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if categoryBreakdown.isEmpty {
                Text("No categorized expenses for this month.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 12) {
                    ForEach(categoryBreakdown) { item in
                        VStack(spacing: 6) {
                            HStack {
                                HStack(spacing: 8) {
                                    Image(systemName: item.icon)
                                        .font(.caption)
                                        .foregroundStyle(.white)
                                        .frame(width: 24, height: 24)
                                        .background(Color(hex: item.colorHex))
                                        .clipShape(Circle())

                                    Text(item.name)
                                        .font(.subheadline.weight(.medium))
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(item.amount.currencyString(code: currencyCode))
                                        .font(.subheadline.weight(.semibold))
                                    Text(String(format: "%.1f%% · %d txns", item.percentage, item.count))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            // Progress bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.primary.opacity(0.08))
                                        .frame(height: 6)

                                    Capsule()
                                        .fill(Color.primary)
                                        .frame(width: max(4, geo.size.width * CGFloat(item.percentage / 100.0)), height: 6)
                                }
                            }
                            .frame(height: 6)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var quickStatsSection: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Daily Average")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(dailyAverage.currencyString(code: currencyCode))
                    .font(.headline.weight(.semibold))
                Text("over \(daysInMonth) days")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("Transactions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(transactions.count)")
                    .font(.headline.weight(.semibold))
                Text("\(expenseTransactions.count) exp · \(incomeTransactions.count) inc")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private struct SheetDayGroup: Identifiable {
        let date: Date
        let title: String
        let transactions: [Transaction]
        var id: Date { date }
    }

    private var dayGroups: [SheetDayGroup] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: transactions) { cal.startOfDay(for: $0.date) }
        let sortedDates = grouped.keys.sorted(by: >)
        return sortedDates.map { dayDate in
            let txns = (grouped[dayDate] ?? []).sorted { $0.date > $1.date }
            return SheetDayGroup(date: dayDate, title: dayDate.daySectionDisplay, transactions: txns)
        }
    }

    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Transactions in \(monthTitle)")
                    .font(.headline)
                Spacer()
                Text("\(transactions.count) total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if transactions.isEmpty {
                Text("No transactions found for this month.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 12) {
                    ForEach(dayGroups) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(group.title)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)

                                Spacer()

                                let dayExpense = group.transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
                                if dayExpense > 0 {
                                    Text("-\(dayExpense.currencyString(code: currencyCode))")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 4)

                            VStack(spacing: 6) {
                                ForEach(group.transactions) { txn in
                                    TransactionRowView(transaction: txn, showDate: false)
                                        .padding(12)
                                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            editingTransaction = txn
                                            showEditSheet = true
                                        }
                                        .contextMenu {
                                            Button {
                                                editingTransaction = txn
                                                showEditSheet = true
                                            } label: {
                                                Label("Edit Transaction", systemImage: "pencil")
                                            }
                                        } preview: {
                                            TransactionPreviewCard(transaction: txn)
                                        }
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
