import SwiftUI
import SwiftData

/// Modern, simplified category-by-category spending comparison card.
///
/// Compares:
/// 1. This Month vs Last Month (e.g., Food & Dining, Transport, Shopping)
/// 2. This Year vs Last Year
///
/// Features:
/// - Category-level spending deltas (current vs previous amount, % change)
/// - Proportional dual-bar comparison indicators
/// - Clean, uncluttered typography readable at a glance
/// - Expandable toggle for top categories vs all categories
struct CategorySpendingComparisonCard: View {

    let transactions: [Transaction]
    let currencyCode: String

    var targetDate: Date = .now
    var onSelectCategory: ((String) -> Void)? = nil

    enum ComparisonPeriod: String, CaseIterable, Identifiable {
        case month = "Month vs Month"
        case year = "Year vs Year"

        var id: String { rawValue }
    }

    @State private var period: ComparisonPeriod = .month
    @State private var showAllCategories: Bool = false

    // MARK: - Date Helpers

    // ── Monthly Range ─────────────────────────────────────────────────────────
    private var thisMonthStart: Date { targetDate.startOfMonth }
    private var thisMonthEnd: Date { targetDate.endOfMonth }
    private var lastMonthStart: Date { targetDate.adding(.month, value: -1).startOfMonth }
    private var lastMonthEnd: Date { targetDate.adding(.month, value: -1).endOfMonth }

    // ── Yearly Range ──────────────────────────────────────────────────────────
    private var currentYear: Int { Calendar.current.component(.year, from: targetDate) }
    private var lastYear: Int { currentYear - 1 }

    // MARK: - Aggregations

    private var currentExpenseTransactions: [Transaction] {
        transactions.filter { txn in
            guard txn.type == .expense else { return false }
            switch period {
            case .month:
                return txn.date >= thisMonthStart && txn.date <= thisMonthEnd
            case .year:
                return Calendar.current.component(.year, from: txn.date) == currentYear
            }
        }
    }

    private var previousExpenseTransactions: [Transaction] {
        transactions.filter { txn in
            guard txn.type == .expense else { return false }
            switch period {
            case .month:
                return txn.date >= lastMonthStart && txn.date <= lastMonthEnd
            case .year:
                return Calendar.current.component(.year, from: txn.date) == lastYear
            }
        }
    }

    private var currentTotalExpense: Double {
        currentExpenseTransactions.reduce(0) { $0 + $1.amount }
    }

    private var previousTotalExpense: Double {
        previousExpenseTransactions.reduce(0) { $0 + $1.amount }
    }

    private var overallDiff: Double {
        currentTotalExpense - previousTotalExpense
    }

    private var overallPctChange: Double? {
        guard previousTotalExpense > 0 else { return nil }
        return ((currentTotalExpense - previousTotalExpense) / previousTotalExpense) * 100.0
    }

    // MARK: - Category Comparison Model

    struct CategoryComparisonItem: Identifiable {
        let id: String
        let name: String
        let icon: String
        let colorHex: String
        let currentAmount: Double
        let previousAmount: Double

        var diff: Double { currentAmount - previousAmount }

        var pctChange: Double? {
            guard previousAmount > 0 else { return nil }
            return ((currentAmount - previousAmount) / previousAmount) * 100.0
        }
    }

    private var categoryComparisons: [CategoryComparisonItem] {
        // Collect all distinct category names across both periods
        var categoryMap: [String: (icon: String, hex: String, current: Double, previous: Double)] = [:]

        for txn in currentExpenseTransactions {
            let name = txn.category?.name ?? "Other"
            let icon = txn.category?.icon ?? "folder"
            let hex = txn.category?.colorHex ?? "#1C1C1E"
            let existing = categoryMap[name] ?? (icon: icon, hex: hex, current: 0.0, previous: 0.0)
            categoryMap[name] = (icon: icon, hex: hex, current: existing.current + txn.amount, previous: existing.previous)
        }

        for txn in previousExpenseTransactions {
            let name = txn.category?.name ?? "Other"
            let icon = txn.category?.icon ?? "folder"
            let hex = txn.category?.colorHex ?? "#1C1C1E"
            let existing = categoryMap[name] ?? (icon: icon, hex: hex, current: 0.0, previous: 0.0)
            categoryMap[name] = (icon: icon, hex: hex, current: existing.current, previous: existing.previous + txn.amount)
        }

        return categoryMap.map { name, val in
            CategoryComparisonItem(
                id: name,
                name: name,
                icon: val.icon,
                colorHex: val.hex,
                currentAmount: val.current,
                previousAmount: val.previous
            )
        }
        .sorted {
            if $0.currentAmount != $1.currentAmount {
                return $0.currentAmount > $1.currentAmount
            }
            return $0.previousAmount > $1.previousAmount
        }
    }

    private var displayedCategories: [CategoryComparisonItem] {
        if showAllCategories || categoryComparisons.count <= 5 {
            return categoryComparisons
        }
        return Array(categoryComparisons.prefix(5))
    }

    private var maxCategoryAmount: Double {
        let maxCurrent = categoryComparisons.map(\.currentAmount).max() ?? 1.0
        let maxPrev = categoryComparisons.map(\.previousAmount).max() ?? 1.0
        return max(1.0, max(maxCurrent, maxPrev))
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Header Row & Period Picker
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Spending Comparison", systemImage: "arrow.left.arrow.right")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()
                }

                Picker("Period", selection: $period) {
                    ForEach(ComparisonPeriod.allCases) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Overall Summary Card
            overallSummaryCard

            // Category Comparisons List
            if categoryComparisons.isEmpty {
                emptyComparisonView
            } else {
                VStack(spacing: 12) {
                    ForEach(displayedCategories) { item in
                        categoryComparisonRow(item)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelectCategory?(item.name)
                            }
                    }

                    // Show more / less button
                    if categoryComparisons.count > 5 {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showAllCategories.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(showAllCategories ? "Show Top 5" : "Show All \(categoryComparisons.count) Categories")
                                Image(systemName: showAllCategories ? "chevron.up" : "chevron.down")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Subviews

    // ── Overall Summary ───────────────────────────────────────────────────────
    private var overallSummaryCard: some View {
        let isCurrentMonth = targetDate.isSameMonth(as: .now)
        let currentLabel = period == .month ? (isCurrentMonth ? "This Month (\(targetDate.shortMonthString))" : targetDate.shortMonthString) : "\(currentYear)"
        let previousLabel = period == .month ? targetDate.adding(.month, value: -1).shortMonthString : "\(lastYear)"

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(currentLabel)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(currentTotalExpense.currencyString(code: currencyCode))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)

                Text("vs \(previousLabel): \(previousTotalExpense.currencyString(code: currencyCode))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if previousTotalExpense > 0 {
                let isSaved = overallDiff < 0
                VStack(alignment: .trailing, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: isSaved ? "arrow.down.right" : "arrow.up.right")
                        Text(String(format: "%@%.1f%%", overallDiff >= 0 ? "+" : "", overallPctChange ?? 0))
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isSaved ? .green : .primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(isSaved ? Color.green.opacity(0.12) : Color.primary.opacity(0.08))
                    .clipShape(Capsule())

                    Text(isSaved ? "Saved \(Swift.abs(overallDiff).currencyString(code: currencyCode))" : "Spent \(overallDiff.currencyString(code: currencyCode)) more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No previous data")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // ── Category Row ──────────────────────────────────────────────────────────
    private func categoryComparisonRow(_ item: CategoryComparisonItem) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                // Category Icon
                Image(systemName: item.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color(hex: item.colorHex))
                    .clipShape(Circle())

                // Category Name
                Text(item.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer()

                // Amounts & Delta
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.currentAmount.currencyString(code: currencyCode))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)

                        // Delta badge
                        if item.previousAmount > 0 {
                            let isSaved = item.diff < 0
                            Text(String(format: "%@%.0f%%", item.diff >= 0 ? "+" : "", item.pctChange ?? 0))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(isSaved ? .green : .primary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(isSaved ? Color.green.opacity(0.12) : Color.primary.opacity(0.08))
                                .clipShape(Capsule())
                        } else if item.currentAmount > 0 && item.previousAmount == 0 {
                            Text("New")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.primary.opacity(0.06))
                                .clipShape(Capsule())
                        }
                    }

                    if item.previousAmount > 0 {
                        Text("prev \(item.previousAmount.currencyString(code: currencyCode))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if onSelectCategory != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 2)
                }
            }

            // Proportional Comparison Bar
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let currentWidth = max(2, totalWidth * CGFloat(item.currentAmount / maxCategoryAmount))
                let prevWidth = max(2, totalWidth * CGFloat(item.previousAmount / maxCategoryAmount))

                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.primary.opacity(0.05))
                        .frame(height: 4)

                    // Previous period subtle benchmark line/bar
                    if item.previousAmount > 0 {
                        Capsule()
                            .fill(Color.primary.opacity(0.18))
                            .frame(width: prevWidth, height: 4)
                    }

                    // Current period bar
                    Capsule()
                        .fill(Color(hex: item.colorHex))
                        .frame(width: currentWidth, height: 4)
                }
            }
            .frame(height: 4)
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }

    // ── Empty State ───────────────────────────────────────────────────────────
    private var emptyComparisonView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            Text("No comparison data available")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Text("Add transactions across consecutive months to see category spending changes.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}
