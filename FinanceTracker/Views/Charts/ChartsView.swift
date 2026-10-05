import SwiftUI
import SwiftData

/// Container tab for all chart visualisations and spending comparisons.
///
/// Hosts:
///   - `CategorySpendingComparisonCard` — MoM and YoY category-by-category spending comparisons
///   - Period toggle (Monthly / Weekly)
///   - `SpendingDonutChart` — category breakdown for the current period
///   - `TrendLineChart`     — income vs. expense over the past 6 months
struct ChartsView: View {

    @Environment(AppState.self) private var appState
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

    private struct DrilldownTarget: Identifiable {
        let categoryName: String
        var id: String { categoryName }
    }

    @State private var period: SummaryPeriod = .monthly
    @State private var selectedMonthDate: Date = Date.now.startOfMonth
    @State private var showMonthBreakdownSheet: Bool = false
    @State private var drilldownTarget: DrilldownTarget? = nil

    private var ledgerTransactions: [Transaction] {
        guard let ledger = appState.selectedLedger else { return allTransactions }
        return allTransactions.filter { $0.ledger?.id == ledger.id || $0.ledger == nil }
    }

    private var currencyCode: String {
        appState.selectedLedger?.currency ?? "MYR"
    }

    private var availableMonths: [Date] {
        var set = Set<Date>()
        for txn in ledgerTransactions {
            set.insert(txn.date.startOfMonth)
        }
        for offset in 0..<12 {
            if let d = Calendar.current.date(byAdding: .month, value: -offset, to: .now)?.startOfMonth {
                set.insert(d)
            }
        }
        return set.sorted(by: >)
    }

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if isRegularWidth {
                    // iPad Multi-Column Layout
                    VStack(spacing: 20) {
                        monthNavigator
                        MonthConclusionCard(
                            selectedDate: selectedMonthDate,
                            transactions: ledgerTransactions,
                            currencyCode: currencyCode,
                            onViewTransactions: {
                                showMonthBreakdownSheet = true
                            }
                        )
                        .accessibilityIdentifier("monthConclusionCard")

                        HStack(alignment: .top, spacing: 20) {
                            // Column 1: Comparisons & Category Explorer
                            VStack(spacing: 20) {
                                CategorySpendingComparisonCard(
                                    transactions: ledgerTransactions,
                                    currencyCode: currencyCode,
                                    targetDate: selectedMonthDate,
                                    onSelectCategory: { categoryName in
                                        drilldownTarget = DrilldownTarget(categoryName: categoryName)
                                    }
                                )
                                .accessibilityIdentifier("spendingComparisonCard")

                                categoryExplorerCard
                                    .accessibilityIdentifier("categoryExpenseExplorer")
                            }
                            .frame(maxWidth: .infinity)

                            // Column 2: Donut Chart & Trend Line
                            VStack(spacing: 20) {
                                Picker("Period", selection: $period) {
                                    ForEach(SummaryPeriod.allCases) { p in
                                        Text(p.rawValue).tag(p)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .accessibilityIdentifier("chartsPeriodToggle")

                                SpendingDonutChart(
                                    period: period,
                                    targetDate: selectedMonthDate,
                                    onSelectCategory: { categoryName in
                                        drilldownTarget = DrilldownTarget(categoryName: categoryName)
                                    }
                                )
                                .accessibilityIdentifier("spendingDonutChart")

                                TrendLineChart(
                                    targetDate: selectedMonthDate,
                                    onSelectMonth: { tappedDate in
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            selectedMonthDate = tappedDate
                                        }
                                    }
                                )
                                .accessibilityIdentifier("trendLineChart")
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                } else {
                    // iPhone Stacked Layout
                    VStack(spacing: 18) {
                        monthNavigator

                        MonthConclusionCard(
                            selectedDate: selectedMonthDate,
                            transactions: ledgerTransactions,
                            currencyCode: currencyCode,
                            onViewTransactions: {
                                showMonthBreakdownSheet = true
                            }
                        )
                        .accessibilityIdentifier("monthConclusionCard")

                        CategorySpendingComparisonCard(
                            transactions: ledgerTransactions,
                            currencyCode: currencyCode,
                            targetDate: selectedMonthDate,
                            onSelectCategory: { categoryName in
                                drilldownTarget = DrilldownTarget(categoryName: categoryName)
                            }
                        )
                        .accessibilityIdentifier("spendingComparisonCard")

                        categoryExplorerCard
                            .accessibilityIdentifier("categoryExpenseExplorer")

                        Picker("Period", selection: $period) {
                            ForEach(SummaryPeriod.allCases) { p in
                                Text(p.rawValue).tag(p)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 2)
                        .accessibilityIdentifier("chartsPeriodToggle")

                        SpendingDonutChart(
                            period: period,
                            targetDate: selectedMonthDate,
                            onSelectCategory: { categoryName in
                                drilldownTarget = DrilldownTarget(categoryName: categoryName)
                            }
                        )
                        .accessibilityIdentifier("spendingDonutChart")

                        TrendLineChart(
                            targetDate: selectedMonthDate,
                            onSelectMonth: { tappedDate in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedMonthDate = tappedDate
                                }
                            }
                        )
                        .accessibilityIdentifier("trendLineChart")
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Analytics & Charts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    LedgerSwitcherView()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    SyncStatusBadge()
                }
            }
            .sheet(isPresented: $showMonthBreakdownSheet) {
                let monthTxns = ledgerTransactions.filter {
                    $0.date >= selectedMonthDate.startOfMonth && $0.date <= selectedMonthDate.endOfMonth
                }
                let prevStart = selectedMonthDate.adding(.month, value: -1).startOfMonth
                let prevEnd = selectedMonthDate.adding(.month, value: -1).endOfMonth
                let prevTxns = ledgerTransactions.filter {
                    $0.date >= prevStart && $0.date <= prevEnd
                }

                MonthBreakdownSheet(
                    monthTitle: selectedMonthDate.monthYearString,
                    monthDate: selectedMonthDate,
                    transactions: monthTxns,
                    previousMonthTransactions: prevTxns,
                    currencyCode: currencyCode
                )
            }
            .sheet(item: $drilldownTarget) { target in
                CategoryExpensesDetailSheet(
                    monthDate: selectedMonthDate,
                    currencyCode: currencyCode,
                    allMonthTransactions: ledgerTransactions,
                    selectedCategoryName: target.categoryName
                )
                .id(target.id)
            }
        }
    }

    // MARK: - Month Navigator

    private var monthNavigator: some View {
        HStack {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedMonthDate = selectedMonthDate.adding(.month, value: -1).startOfMonth
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .padding(8)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Circle())
            }

            Spacer()

            Menu {
                ForEach(availableMonths, id: \.self) { date in
                    Button {
                        withAnimation { selectedMonthDate = date }
                    } label: {
                        HStack {
                            Text(date.monthYearString)
                            if date.isSameMonth(as: selectedMonthDate) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(selectedMonthDate.monthYearString)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.06))
                .clipShape(Capsule())
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedMonthDate = selectedMonthDate.adding(.month, value: 1).startOfMonth
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .padding(8)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Circle())
            }

            if !selectedMonthDate.isSameMonth(as: .now) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedMonthDate = Date.now.startOfMonth
                    }
                } label: {
                    Text("Today")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(Capsule())
                }
                .padding(.leading, 4)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Category Explorer Card

    private var categoryExplorerCard: some View {
        let monthTxns = ledgerTransactions.filter {
            $0.type == .expense &&
            $0.date >= selectedMonthDate.startOfMonth &&
            $0.date <= selectedMonthDate.endOfMonth
        }
        let grouped = Dictionary(grouping: monthTxns, by: { $0.category?.name ?? "Uncategorised" })
        let sortedCategories = grouped.map { (catName, txns) -> (name: String, total: Double, count: Int, category: Category?) in
            (name: catName, total: txns.reduce(0) { $0 + $1.amount }, count: txns.count, category: txns.first?.category)
        }.sorted { $0.total > $1.total }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Category Expense Explorer")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Tap any category to inspect expenses sorted highest first")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            if sortedCategories.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "tray")
                        .foregroundStyle(.secondary)
                    Text("No expenses recorded for \(selectedMonthDate.monthYearString)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(sortedCategories, id: \.name) { item in
                            Button {
                                drilldownTarget = DrilldownTarget(categoryName: item.name)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: item.category?.icon ?? "folder")
                                            .font(.caption.bold())
                                            .foregroundStyle(item.category.map { Color(hex: $0.colorHex) } ?? .primary)
                                            .frame(width: 24, height: 24)
                                            .background(
                                                (item.category.map { Color(hex: $0.colorHex) } ?? .primary).opacity(0.12)
                                            )
                                            .clipShape(Circle())

                                        Text(item.name)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.total.currencyString(code: currencyCode))
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(.primary)

                                        HStack(spacing: 4) {
                                            Text("\(item.count) \(item.count == 1 ? "expense" : "expenses")")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            Text("·")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            Text("Highest First")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(.primary)
                                        }
                                    }
                                }
                                .padding(12)
                                .background(Color(uiColor: .secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("explorerCat_\(item.name)")
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 2)
    }
}
