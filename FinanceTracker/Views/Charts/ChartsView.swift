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
        var transactionType: TransactionType = .expense
        var id: String { "\(categoryName)_\(transactionType.rawValue)" }
    }

    @State private var period: SummaryPeriod = .monthly
    @State private var selectedMonthDate: Date = Date.now.startOfMonth
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

                        HStack(alignment: .top, spacing: 20) {
                            // Column 1: Comparisons
                            CategorySpendingComparisonCard(
                                transactions: ledgerTransactions,
                                currencyCode: currencyCode,
                                targetDate: selectedMonthDate,
                                onSelectCategory: { categoryName, type in
                                    drilldownTarget = DrilldownTarget(categoryName: categoryName, transactionType: type)
                                }
                            )
                            .accessibilityIdentifier("spendingComparisonCard")
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
                                    onSelectCategory: { categoryName, type in
                                        drilldownTarget = DrilldownTarget(categoryName: categoryName, transactionType: type)
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

                        CategorySpendingComparisonCard(
                            transactions: ledgerTransactions,
                            currencyCode: currencyCode,
                            targetDate: selectedMonthDate,
                            onSelectCategory: { categoryName, type in
                                drilldownTarget = DrilldownTarget(categoryName: categoryName, transactionType: type)
                            }
                        )
                        .accessibilityIdentifier("spendingComparisonCard")

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
                            onSelectCategory: { categoryName, type in
                                drilldownTarget = DrilldownTarget(categoryName: categoryName, transactionType: type)
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
            }
            .sheet(item: $drilldownTarget) { target in
                CategoryExpensesDetailSheet(
                    monthDate: selectedMonthDate,
                    currencyCode: currencyCode,
                    allMonthTransactions: ledgerTransactions,
                    selectedCategoryName: target.categoryName,
                    transactionType: target.transactionType
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
}

