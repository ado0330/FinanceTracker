import SwiftUI
import Charts
import SwiftData

/// Interactive Income vs Expenses chart supporting side-by-side grouped bars
/// and dual trend lines, synchronized with the active selected month.
struct TrendLineChart: View {

    // MARK: - Environment & State
    @Environment(AppState.self) private var appState
    @Query(sort: \Transaction.date) private var allTransactions: [Transaction]

    var targetDate: Date = .now
    var onSelectMonth: ((Date) -> Void)? = nil

    // Display mode: Grouped Bars (default) or Trend Lines
    @State private var chartStyle: ChartStyle = .bars
    @State private var hoveredDate: Date? = nil

    enum ChartStyle: String, CaseIterable, Identifiable {
        case bars  = "Bars"
        case lines = "Lines"

        var id: String { rawValue }
    }

    // MARK: - Data Structures
    struct MonthComparisonItem: Identifiable {
        let id = UUID()
        let monthStart: Date
        let monthLabel: String      // e.g. "Oct"
        let yearLabel: String       // e.g. "2026"
        let income: Double
        let expense: Double
        let net: Double
        let isSelected: Bool
    }

    struct ChartBarEntry: Identifiable {
        let id = UUID()
        let monthLabel: String
        let monthStart: Date
        let type: String            // "Income" or "Expenses"
        let amount: Double
        let isIncome: Bool
    }

    // MARK: - Computed Properties
    private var currency: String {
        appState.selectedLedger?.currency ?? "MYR"
    }

    private var ledgerTransactions: [Transaction] {
        guard let l = appState.selectedLedger else { return allTransactions }
        return allTransactions.filter { $0.ledger?.id == l.id }
    }

    /// 6-month window ending with targetDate (or current date if target is in the past)
    private var windowMonths: [Date] {
        let cal = Calendar.current
        let baseDate = targetDate.startOfMonth
        return (0..<6).reversed().compactMap { offset in
            cal.date(byAdding: .month, value: -offset, to: baseDate)?.startOfMonth
        }
    }

    private var monthItems: [MonthComparisonItem] {
        let cal = Calendar.current
        return windowMonths.map { start in
            let txns = ledgerTransactions.filter {
                cal.isDate($0.date, equalTo: start, toGranularity: .month)
            }
            let inc = txns.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
            let exp = txns.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
            let isCurrent = cal.isDate(start, equalTo: targetDate, toGranularity: .month)

            return MonthComparisonItem(
                monthStart: start,
                monthLabel: start.shortMonthString,
                yearLabel: String(cal.component(.year, from: start)),
                income: inc,
                expense: exp,
                net: inc - exp,
                isSelected: isCurrent
            )
        }
    }

    /// Flattened series for grouped BarMark
    private var barEntries: [ChartBarEntry] {
        var list: [ChartBarEntry] = []
        for item in monthItems {
            list.append(ChartBarEntry(
                monthLabel: item.monthLabel,
                monthStart: item.monthStart,
                type: "Income",
                amount: item.income,
                isIncome: true
            ))
            list.append(ChartBarEntry(
                monthLabel: item.monthLabel,
                monthStart: item.monthStart,
                type: "Expenses",
                amount: item.expense,
                isIncome: false
            ))
        }
        return list
    }

    /// The item currently selected or hovered
    private var activeItem: MonthComparisonItem? {
        if let h = hoveredDate {
            return monthItems.min(by: { abs($0.monthStart.timeIntervalSince(h)) < abs($1.monthStart.timeIntervalSince(h)) })
        }
        return monthItems.first { $0.isSelected } ?? monthItems.last
    }

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // ── Header & Chart Style Toggle ───────────────────────────────
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Income vs Expenses", systemImage: "chart.bar.xaxis")
                        .font(.headline)
                        .foregroundStyle(Color.primary)

                    if let active = activeItem {
                        Text("\(active.monthStart.monthYearString)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Style Toggle: Bars vs Lines
                Picker("Chart Style", selection: $chartStyle) {
                    ForEach(ChartStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }

            // ── Active Month Financial Metrics Strip ──────────────────────
            if let active = activeItem {
                metricsStrip(active)
            }

            // ── Chart Content ─────────────────────────────────────────────
            if monthItems.allSatisfy({ $0.income == 0 && $0.expense == 0 }) {
                emptyState
            } else {
                if chartStyle == .bars {
                    groupedBarsChart
                } else {
                    dualLinesChart
                }

                // Legend & Selection Hint
                HStack {
                    legendRow
                    Spacer()
                    Text("Tap bar to inspect")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
    }

    // MARK: - Metrics Strip
    private func metricsStrip(_ item: MonthComparisonItem) -> some View {
        HStack(spacing: 8) {
            metricCard(
                label: "Income",
                value: "+\(item.income.currencyString(code: currency))",
                color: Color(.systemGreen),
                icon: "arrow.up.circle.fill"
            )

            metricCard(
                label: "Expenses",
                value: "−\(item.expense.currencyString(code: currency))",
                color: Color(.systemRed),
                icon: "arrow.down.circle.fill"
            )

            metricCard(
                label: "Net",
                value: item.net >= 0 ? "+\(item.net.currencyString(code: currency))" : "−\(abs(item.net).currencyString(code: currency))",
                color: item.net >= 0 ? Color(.systemGreen) : Color(.systemRed),
                icon: item.net >= 0 ? "plus.circle.fill" : "minus.circle.fill"
            )
        }
    }

    private func metricCard(label: String, value: String, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Grouped Bar Chart (Side-by-Side)
    private var groupedBarsChart: some View {
        Chart {
            ForEach(barEntries) { entry in
                BarMark(
                    x: .value("Month", entry.monthLabel),
                    y: .value("Amount", entry.amount)
                )
                .foregroundStyle(entry.isIncome ? Color(.systemGreen) : Color(.systemRed))
                .position(by: .value("Type", entry.type))
                .cornerRadius(5)
                .opacity(isMonthSelected(entry.monthStart) ? 1.0 : 0.75)
            }

            // Highlight line under selected month
            if let active = activeItem {
                RuleMark(x: .value("Month", active.monthLabel))
                    .foregroundStyle(Color.primary.opacity(0.12))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                AxisValueLabel {
                    if let d = value.as(Double.self) {
                        Text(d.compactCurrencyString(code: currency))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let label = value.as(String.self) {
                        let isSelected = activeItem?.monthLabel == label
                        Text(label)
                            .font(.caption.weight(isSelected ? .bold : .regular))
                            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        if let label: String = proxy.value(atX: location.x) {
                            if let match = monthItems.first(where: { $0.monthLabel == label }) {
                                onSelectMonth?(match.monthStart)
                            }
                        }
                    }
            }
        }
        .frame(height: 200)
    }

    // MARK: - Dual Lines Chart (Clean, No Murky Overlaps)
    private var dualLinesChart: some View {
        Chart {
            // ── Income Line ───────────────────────────────────────────────
            ForEach(monthItems) { item in
                LineMark(
                    x: .value("Month", item.monthLabel),
                    y: .value("Amount", item.income)
                )
                .foregroundStyle(Color(.systemGreen))
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.monotone)

                PointMark(
                    x: .value("Month", item.monthLabel),
                    y: .value("Amount", item.income)
                )
                .foregroundStyle(Color(.systemGreen))
                .symbolSize(item.isSelected ? 50 : 25)
            }

            // ── Expense Line ──────────────────────────────────────────────
            ForEach(monthItems) { item in
                LineMark(
                    x: .value("Month", item.monthLabel),
                    y: .value("Amount", item.expense)
                )
                .foregroundStyle(Color(.systemRed))
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.monotone)

                PointMark(
                    x: .value("Month", item.monthLabel),
                    y: .value("Amount", item.expense)
                )
                .foregroundStyle(Color(.systemRed))
                .symbolSize(item.isSelected ? 50 : 25)
            }

            // Active Month Marker
            if let active = activeItem {
                RuleMark(x: .value("Month", active.monthLabel))
                    .foregroundStyle(Color.primary.opacity(0.15))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                AxisValueLabel {
                    if let d = value.as(Double.self) {
                        Text(d.compactCurrencyString(code: currency))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let label = value.as(String.self) {
                        let isSelected = activeItem?.monthLabel == label
                        Text(label)
                            .font(.caption.weight(isSelected ? .bold : .regular))
                            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        if let label: String = proxy.value(atX: location.x) {
                            if let match = monthItems.first(where: { $0.monthLabel == label }) {
                                onSelectMonth?(match.monthStart)
                            }
                        }
                    }
            }
        }
        .frame(height: 200)
    }

    // MARK: - Legend
    private var legendRow: some View {
        HStack(spacing: 16) {
            HStack(spacing: 5) {
                Circle()
                    .fill(Color(.systemGreen))
                    .frame(width: 8, height: 8)
                Text("Income")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 5) {
                Circle()
                    .fill(Color(.systemRed))
                    .frame(width: 8, height: 8)
                Text("Expenses")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 38))
                .foregroundStyle(.secondary.opacity(0.5))
                .padding(.top, 16)

            Text("No Income or Expense History")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Record income and expenses to view side-by-side monthly comparisons.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.tertiarySystemFill).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Helpers
    private func isMonthSelected(_ date: Date) -> Bool {
        Calendar.current.isDate(date, equalTo: targetDate, toGranularity: .month)
    }
}
