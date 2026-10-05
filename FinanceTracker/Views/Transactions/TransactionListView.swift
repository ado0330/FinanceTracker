import SwiftUI
import SwiftData

/// Displays transactions for the active ledger with:
/// - Instant month filter pills & toolbar menu (All Months, Oct 2026, Sep 2026, Aug 2026, etc.)
/// - Date-segmented sections (grouped by day, e.g. Today · 4 Oct 2026, Yesterday · 3 Oct 2026)
/// - Daily net spending / income totals in each date section header
/// - Overall monthly conclusion card when a specific past or current month is selected
/// - Swipe-to-delete and tap-to-edit
/// - Tap-to-inspect Month Breakdown sheet with itemized transactions and categories
/// - Clean, distraction-free standalone layout (100% English, monochrome luxury styling)
struct TransactionListView: View {

    // MARK: - Environment & Query
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

    // MARK: - UI State
    @State private var showingAddEdit = false
    @State private var editingTransaction: Transaction? = nil
    @State private var detailTransaction: Transaction? = nil
    @State private var searchText = ""
    @State private var selectedMonthFilter: String? = nil

    // Month breakdown sheet state
    @State private var selectedBreakdownMonthKey: String? = nil

    // MARK: - Computed Properties

    private var currencyCode: String {
        appState.selectedLedger?.currency ?? "MYR"
    }

    private var ledgerTransactions: [Transaction] {
        if let activeLedger = appState.selectedLedger {
            return allTransactions.filter { $0.ledger?.id == activeLedger.id }
        } else {
            return allTransactions
        }
    }

    /// Selectable months combining all months present in transactions plus recent months,
    /// so the user can always pick October, September, August, etc., or All Months.
    private var selectableMonths: [String] {
        var unique = Set(ledgerTransactions.map { $0.date.monthYearDisplay })
        let now = Date.now
        for offset in 0..<6 {
            if let d = Calendar.current.date(byAdding: .month, value: -offset, to: now) {
                unique.insert(d.monthYearDisplay)
            }
        }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return unique.sorted { (lhs, rhs) in
            (fmt.date(from: lhs) ?? .distantPast) > (fmt.date(from: rhs) ?? .distantPast)
        }
    }

    /// Transactions filtered by selected month and search query.
    private var filteredTransactions: [Transaction] {
        var txns = ledgerTransactions

        if let selectedMonth = selectedMonthFilter {
            txns = txns.filter { $0.date.monthYearDisplay == selectedMonth }
        }

        guard !searchText.isEmpty else { return txns }

        let query = searchText.lowercased()
        return txns.filter { txn in
            (txn.name?.lowercased().contains(query) ?? false) ||
            txn.note.lowercased().contains(query) ||
            (txn.category?.name.lowercased().contains(query) ?? false) ||
            txn.tags.contains { $0.name.lowercased().contains(query) }
        }
    }

    /// Grouping of transactions by unique calendar day (start of day), sorted newest to oldest.
    private var dayGroups: [DayGroup] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: filteredTransactions) {
            cal.startOfDay(for: $0.date)
        }
        let sortedDates = grouped.keys.sorted(by: >)
        return sortedDates.map { dayDate in
            let txns = (grouped[dayDate] ?? []).sorted { $0.date > $1.date }
            return DayGroup(
                date: dayDate,
                title: dayDate.daySectionDisplay,
                transactions: txns
            )
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Month Filter Pills (All Months, Oct 2026, Sep 2026, etc.)
                monthFilterPills

                Group {
                    if filteredTransactions.isEmpty && searchText.isEmpty && ledgerTransactions.isEmpty {
                        emptyState
                    } else {
                        mainContent
                    }
                }
            }
            .navigationTitle("Transactions")
            .searchable(text: $searchText, prompt: "Search transactions")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    monthFilterMenu
                }
                ToolbarItem(placement: .principal) {
                    LedgerSwitcherView()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 8) {
                        SyncStatusBadge()

                        Button {
                            editingTransaction = nil
                            showingAddEdit = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityIdentifier("addTransactionButton")
                    }
                }
            }
            .sheet(isPresented: $showingAddEdit) {
                AddEditTransactionView(transaction: $editingTransaction) {
                    showingAddEdit = false
                }
            }
            .sheet(item: Binding(
                get: { selectedBreakdownMonthKey.map { MonthIdentifiable(key: $0) } },
                set: { selectedBreakdownMonthKey = $0?.key }
            )) { monthItem in
                let monthDate = dateForMonthKey(monthItem.key)
                let monthTxns = ledgerTransactions.filter { $0.date.monthYearDisplay == monthItem.key }
                let prevTxns = previousMonthTransactions(for: monthDate)
                MonthBreakdownSheet(
                    monthTitle: monthItem.key,
                    monthDate: monthDate,
                    transactions: monthTxns,
                    previousMonthTransactions: prevTxns,
                    currencyCode: currencyCode
                )
            }
            .sheet(item: $detailTransaction) { txn in
                TransactionDetailSheet(transaction: txn) {
                    editingTransaction = txn
                    showingAddEdit = true
                }
            }
        }
    }

    // MARK: - Month Filter Menu (Toolbar)

    private var monthFilterMenu: some View {
        Menu {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedMonthFilter = nil
                }
            } label: {
                HStack {
                    Text("All Months")
                    if selectedMonthFilter == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .accessibilityIdentifier("menuFilterAllMonths")

            Divider()

            ForEach(selectableMonths, id: \.self) { key in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedMonthFilter = key
                    }
                } label: {
                    HStack {
                        Text(key)
                        if selectedMonthFilter == key {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .accessibilityIdentifier("menuFilterMonth_\(key)")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.subheadline)
                Text(selectedMonthFilter.map { shortMonthYear(for: $0) } ?? "All")
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.06))
            .clipShape(Capsule())
        }
        .accessibilityIdentifier("monthFilterMenu")
    }

    // MARK: - Month Filter Pills

    private var monthFilterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All Months Pill
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedMonthFilter = nil
                    }
                } label: {
                    Text("All")
                        .font(.caption.weight(selectedMonthFilter == nil ? .bold : .medium))
                        .foregroundStyle(selectedMonthFilter == nil ? Color(uiColor: .systemBackground) : .primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(selectedMonthFilter == nil ? Color.primary : Color.primary.opacity(0.06))
                        .clipShape(Capsule())
                }
                .accessibilityIdentifier("filterAllMonthsPill")

                // Individual Month Pills
                ForEach(selectableMonths, id: \.self) { key in
                    let isSelected = selectedMonthFilter == key
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedMonthFilter = key
                        }
                    } label: {
                        Text(shortMonthYear(for: key))
                            .font(.caption.weight(isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? Color(uiColor: .systemBackground) : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isSelected ? Color.primary : Color.primary.opacity(0.06))
                            .clipShape(Capsule())
                    }
                    .accessibilityIdentifier("filterMonthPill_\(key)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    // MARK: - Main Content (Date Grouped)

    private var mainContent: some View {
        List {
            // Selected Month Overview Card
            if let selectedMonth = selectedMonthFilter, searchText.isEmpty {
                Section {
                    selectedMonthConclusionCard(key: selectedMonth)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                }
            }

            // If dayGroups is empty (e.g. selected month has no transactions)
            if dayGroups.isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                            .padding(.top, 16)

                        Text(selectedMonthFilter != nil ? "No transactions in \(selectedMonthFilter!)" : "No matching transactions")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(selectedMonthFilter != nil ? "Switch to All Months or tap + to record a transaction." : "Try adjusting your search query.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        if selectedMonthFilter != nil {
                            Button {
                                withAnimation { selectedMonthFilter = nil }
                            } label: {
                                Text("Show All Months")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(Color.primary.opacity(0.08))
                                    .clipShape(Capsule())
                            }
                            .padding(.top, 4)
                            .padding(.bottom, 16)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            } else {
                // Day-by-Day Grouped Sections
                ForEach(dayGroups) { group in
                    Section(header: daySectionHeader(for: group)) {
                        ForEach(group.transactions) { txn in
                            TransactionRowView(transaction: txn, showDate: false)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingTransaction = txn
                                    showingAddEdit = true
                                }
                                .contextMenu {
                                    Button {
                                        detailTransaction = txn
                                    } label: {
                                        Label("View Details & Photo", systemImage: "photo.on.rectangle")
                                    }

                                    Button {
                                        editingTransaction = txn
                                        showingAddEdit = true
                                    } label: {
                                        Label("Edit Transaction", systemImage: "pencil")
                                    }

                                    Divider()

                                    Button(role: .destructive) {
                                        withAnimation { modelContext.delete(txn) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                } preview: {
                                    TransactionPreviewCard(transaction: txn)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        withAnimation { modelContext.delete(txn) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .accessibilityIdentifier("deleteTxn_\(txn.id)")
                                }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Day Section Header

    private func daySectionHeader(for group: DayGroup) -> some View {
        let dayExpense = group.transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
        let dayIncome = group.transactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }

        return HStack(alignment: .center) {
            Text(group.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer()

            if dayExpense > 0 && dayIncome > 0 {
                HStack(spacing: 6) {
                    Text("+\(dayIncome.compactCurrencyString(code: currencyCode))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                    Text("-\(dayExpense.compactCurrencyString(code: currencyCode))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            } else if dayExpense > 0 {
                Text("-\(dayExpense.currencyString(code: currencyCode))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            } else if dayIncome > 0 {
                Text("+\(dayIncome.currencyString(code: currencyCode))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 2)
        .textCase(nil)
    }

    // MARK: - Selected Month Conclusion Card

    private func selectedMonthConclusionCard(key: String) -> some View {
        let monthDate = dateForMonthKey(key)
        let monthTxns = ledgerTransactions.filter { $0.date.monthYearDisplay == key }
        let expenseTxns = monthTxns.filter { $0.type == .expense }
        let totalExpense = expenseTxns.reduce(0) { $0 + $1.amount }
        let totalIncome = monthTxns.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
        let netSavings = totalIncome - totalExpense

        let prevTxns = previousMonthTransactions(for: monthDate)
        let prevExpense = prevTxns.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
        let expenseDiff = totalExpense - prevExpense
        let pctChange: Double? = prevExpense > 0 ? (expenseDiff / prevExpense) * 100.0 : nil

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MONTH OVERVIEW")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .tracking(1)

                    Text(key)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                }

                Spacer()

                Button {
                    withAnimation {
                        selectedMonthFilter = nil
                    }
                } label: {
                    Text("Show All")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Capsule())
                }
            }

            // Key Metrics Row
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Spent")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(totalExpense.compactCurrencyString(code: currencyCode))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Income")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(totalIncome.compactCurrencyString(code: currencyCode))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.green)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Net")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(netSavings.signedCurrencyString(code: currencyCode))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(netSavings >= 0 ? Color.primary : Color.red)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            // Comparison Summary
            if prevExpense > 0 {
                let isSaved = expenseDiff < 0
                HStack(spacing: 6) {
                    Image(systemName: isSaved ? "arrow.down.right.circle.fill" : "arrow.up.right.circle.fill")
                        .foregroundStyle(isSaved ? .green : .primary)
                        .font(.caption)

                    Text(String(format: "%@%.1f%% (%@) vs previous month",
                                expenseDiff >= 0 ? "+" : "",
                                pctChange ?? 0,
                                Swift.abs(expenseDiff).currencyString(code: currencyCode)))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(isSaved ? .green : .secondary)

                    Spacer()

                    Button {
                        selectedBreakdownMonthKey = key
                    } label: {
                        Text("Breakdown")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        EmptyStateView(
            icon: searchText.isEmpty ? "tray" : "magnifyingglass",
            title: searchText.isEmpty ? "No transactions yet" : "No matching transactions",
            message: searchText.isEmpty ? "Tap + to add your first transaction." : "Try adjusting your search query.",
            buttonTitle: searchText.isEmpty ? "Add Transaction" : nil
        ) {
            editingTransaction = nil
            showingAddEdit = true
        }
        .accessibilityIdentifier("emptyTransactionsView")
    }

    // MARK: - Helpers

    private func shortMonthYear(for key: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        if let d = fmt.date(from: key) {
            let shortFmt = DateFormatter()
            shortFmt.dateFormat = "MMM yyyy"
            return shortFmt.string(from: d)
        }
        return key
    }

    private func dateForMonthKey(_ key: String) -> Date {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt.date(from: key) ?? .now
    }

    private func previousMonthTransactions(for monthDate: Date) -> [Transaction] {
        let prevStart = monthDate.adding(.month, value: -1).startOfMonth
        let prevEnd = monthDate.adding(.month, value: -1).endOfMonth
        return ledgerTransactions.filter { $0.date >= prevStart && $0.date <= prevEnd }
    }
}

// MARK: - Helper Models

private struct DayGroup: Identifiable {
    let date: Date
    let title: String
    let transactions: [Transaction]
    var id: Date { date }
}

private struct MonthIdentifiable: Identifiable {
    let key: String
    var id: String { key }
}
