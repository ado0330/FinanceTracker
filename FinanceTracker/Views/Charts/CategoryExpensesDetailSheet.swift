import SwiftUI
import SwiftData

/// Detailed drill-down sheet allowing users to view all individual expenses
/// for a specific category in the selected month, sorted highest expense first.
///
/// Features:
/// - Category selector pills to jump between Food, Transport, Shopping, etc.
/// - Category executive hero card (Total Spent, % of Month, Avg per txn, Peak txn)
/// - Sort order picker (Highest Expense First by default, Date Newest, Lowest)
/// - Ranked transaction list (#1, #2, #3...) with food photos, notes, and account badges
/// - Native long-press preview card for food photos and review inspection
/// - Tap to edit transaction
struct CategoryExpensesDetailSheet: View {

    let monthDate: Date
    let currencyCode: String
    let allMonthTransactions: [Transaction]

    @State var selectedCategoryName: String
    @State private var sortOption: SortOption = .highestFirst
    @State private var editingTransaction: Transaction? = nil
    @State private var showEditSheet: Bool = false
    @State private var detailTransaction: Transaction? = nil

    @Environment(\.dismiss) private var dismiss

    init(
        monthDate: Date,
        currencyCode: String,
        allMonthTransactions: [Transaction],
        selectedCategoryName: String
    ) {
        self.monthDate = monthDate
        self.currencyCode = currencyCode
        self.allMonthTransactions = allMonthTransactions
        self._selectedCategoryName = State(initialValue: selectedCategoryName)
    }

    enum SortOption: String, CaseIterable, Identifiable {
        case highestFirst = "Highest First"
        case lowestFirst  = "Lowest First"
        case newestDate   = "Newest Date"
        case oldestDate   = "Oldest Date"

        var id: String { rawValue }

        var iconName: String {
            switch self {
            case .highestFirst: return "arrow.down.circle.fill"
            case .lowestFirst:  return "arrow.up.circle"
            case .newestDate:   return "calendar.badge.clock"
            case .oldestDate:   return "calendar"
            }
        }
    }

    // MARK: - Computed Properties

    /// All expense transactions within the target month
    private var monthExpenseTransactions: [Transaction] {
        allMonthTransactions.filter { txn in
            txn.type == .expense &&
            txn.date >= monthDate.startOfMonth &&
            txn.date <= monthDate.endOfMonth
        }
    }

    private var totalMonthExpense: Double {
        monthExpenseTransactions.reduce(0) { $0 + $1.amount }
    }

    /// All distinct categories present in this month's expenses, ordered by total spending descending
    private var availableCategories: [CategoryItem] {
        var map: [String: (icon: String, hex: String, total: Double, count: Int)] = [:]

        for txn in monthExpenseTransactions {
            let name = txn.category?.name ?? "Uncategorised"
            let icon = txn.category?.icon ?? "folder"
            let hex = txn.category?.colorHex ?? "#8E8E93"
            let current = map[name] ?? (icon: icon, hex: hex, total: 0.0, count: 0)
            map[name] = (icon: icon, hex: hex, total: current.total + txn.amount, count: current.count + 1)
        }

        return map.map { name, val in
            CategoryItem(
                name: name,
                icon: val.icon,
                colorHex: val.hex,
                totalAmount: val.total,
                transactionCount: val.count
            )
        }
        .sorted { $0.totalAmount > $1.totalAmount }
    }

    private var activeCategoryItem: CategoryItem? {
        availableCategories.first { $0.name == selectedCategoryName } ?? availableCategories.first
    }

    /// Transactions for the currently selected category
    private var categoryTransactions: [Transaction] {
        monthExpenseTransactions.filter { txn in
            let name = txn.category?.name ?? "Uncategorised"
            return name == selectedCategoryName
        }
    }

    /// Sorted category transactions based on selected sort option (Highest First by default)
    private var sortedTransactions: [Transaction] {
        switch sortOption {
        case .highestFirst:
            return categoryTransactions.sorted { $0.amount > $1.amount }
        case .lowestFirst:
            return categoryTransactions.sorted { $0.amount < $1.amount }
        case .newestDate:
            return categoryTransactions.sorted { $0.date > $1.date }
        case .oldestDate:
            return categoryTransactions.sorted { $0.date < $1.date }
        }
    }

    private var categoryTotal: Double {
        categoryTransactions.reduce(0) { $0 + $1.amount }
    }

    private var categoryPercentage: Double {
        guard totalMonthExpense > 0 else { return 0 }
        return (categoryTotal / totalMonthExpense) * 100.0
    }

    private var categoryAverage: Double {
        guard !categoryTransactions.isEmpty else { return 0 }
        return categoryTotal / Double(categoryTransactions.count)
    }

    private var highestTransactionAmount: Double {
        categoryTransactions.map(\.amount).max() ?? 0
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // 1. Horizontal Category Selector Pills
                    categoryPillsBar

                    // 2. Executive Hero Summary Card
                    heroSummaryCard

                    // 3. Header & Sorting Row
                    listHeaderRow

                    // 4. Ranked Transaction List
                    if sortedTransactions.isEmpty {
                        emptyCategoryState
                    } else {
                        transactionsList
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("\(selectedCategoryName) Expenses")
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
            .sheet(item: $detailTransaction) { txn in
                TransactionDetailSheet(transaction: txn) {
                    editingTransaction = txn
                    showEditSheet = true
                }
            }
        }
    }

    // MARK: - Category Selector Pills

    private var categoryPillsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableCategories) { item in
                    let isSelected = item.name == selectedCategoryName
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedCategoryName = item.name
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: item.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(item.name)
                                .font(.caption.weight(isSelected ? .bold : .medium))
                            Text(item.totalAmount.compactCurrencyString(code: currencyCode))
                                .font(.caption2.weight(.medium))
                                .opacity(isSelected ? 0.9 : 0.6)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(isSelected ? Color.primary : Color.primary.opacity(0.06))
                        .foregroundStyle(isSelected ? Color(uiColor: .systemBackground) : .primary)
                        .clipShape(Capsule())
                    }
                    .accessibilityIdentifier("catPill_\(item.name)")
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Hero Summary Card

    private var heroSummaryCard: some View {
        let active = activeCategoryItem
        let colorHex = active?.colorHex ?? "#1C1C1E"
        let icon = active?.icon ?? "folder"

        return VStack(spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color(hex: colorHex))
                    .clipShape(Circle())
                    .shadow(color: Color(hex: colorHex).opacity(0.3), radius: 6, y: 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(monthDate.monthYearString.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(.secondary)

                    Text(selectedCategoryName)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Total Spent")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(categoryTotal.currencyString(code: currencyCode))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                }
            }

            Divider()

            // Key Metrics Grid (4 stats)
            HStack(spacing: 8) {
                metricCell(
                    title: "Month Share",
                    value: String(format: "%.1f%%", categoryPercentage),
                    subtitle: "of total spend"
                )

                metricCell(
                    title: "Transactions",
                    value: "\(categoryTransactions.count)",
                    subtitle: "total entries"
                )

                metricCell(
                    title: "Average",
                    value: categoryAverage.compactCurrencyString(code: currencyCode),
                    subtitle: "per spend"
                )

                metricCell(
                    title: "Highest Single",
                    value: highestTransactionAmount.compactCurrencyString(code: currencyCode),
                    subtitle: "peak expense"
                )
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func metricCell(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            Text(subtitle)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - List Header & Sorting

    private var listHeaderRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Itemized Expenses")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("Sorted from highest expense to lowest")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Sort Menu
            Menu {
                ForEach(SortOption.allCases) { opt in
                    Button {
                        withAnimation { sortOption = opt }
                    } label: {
                        HStack {
                            Label(opt.rawValue, systemImage: opt.iconName)
                            if sortOption == opt {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: sortOption.iconName)
                        .font(.caption2)
                    Text(sortOption.rawValue)
                        .font(.caption.weight(.semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.06))
                .clipShape(Capsule())
                .foregroundStyle(.primary)
            }
            .accessibilityIdentifier("sortOrderMenu")
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    // MARK: - Transactions List (Ranked Highest First)

    private var transactionsList: some View {
        VStack(spacing: 10) {
            ForEach(Array(sortedTransactions.enumerated()), id: \.element.id) { index, txn in
                rankedTransactionRow(index: index + 1, transaction: txn)
            }
        }
    }

    private func rankedTransactionRow(index: Int, transaction: Transaction) -> some View {
        HStack(spacing: 12) {

            // Rank Badge
            rankBadge(index)

            // Content
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(transaction.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if transaction.receiptImageData != nil {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }

                    if !transaction.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Image(systemName: "text.bubble.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 6) {
                    Text(transaction.date.shortDisplay)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if let acc = transaction.account {
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text(acc.name)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .foregroundStyle(.secondary)
                    }

                    // Note / Review snippet if present
                    let noteSnippet = transaction.note.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !noteSnippet.isEmpty && noteSnippet != transaction.displayName {
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text("\"\(noteSnippet)\"")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Amount
            Text(transaction.amount.currencyString(code: currencyCode))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color(.label))
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            editingTransaction = transaction
            showEditSheet = true
        }
        .contextMenu {
            Button {
                detailTransaction = transaction
            } label: {
                Label("View Details & Photo", systemImage: "photo.on.rectangle")
            }

            Button {
                editingTransaction = transaction
                showEditSheet = true
            } label: {
                Label("Edit Transaction", systemImage: "pencil")
            }
        } preview: {
            TransactionPreviewCard(transaction: transaction)
        }
    }

    private func rankBadge(_ rank: Int) -> some View {
        Text("#\(rank)")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(rank <= 3 ? Color(uiColor: .systemBackground) : .secondary)
            .frame(width: 32, height: 32)
            .background(rank <= 3 ? Color.primary : Color.primary.opacity(0.06))
            .clipShape(Circle())
    }

    // MARK: - Empty State

    private var emptyCategoryState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
                .padding(.top, 24)

            Text("No \(selectedCategoryName) expenses")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("No transactions found under this category for \(monthDate.monthYearString).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Helper Data Model

private struct CategoryItem: Identifiable {
    let name: String
    let icon: String
    let colorHex: String
    let totalAmount: Double
    let transactionCount: Int

    var id: String { name }
}
