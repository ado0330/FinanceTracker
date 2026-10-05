import SwiftUI
import Charts
import SwiftData

/// A donut chart that shows spending breakdown by category for the active ledger.
///
/// - Expense transactions for the selected period are grouped by category.
/// - Each slice is coloured with the category's own `colorHex`.
/// - Tapping a slice highlights it and shows a detail callout.
/// - If there are no expense transactions, an empty state is displayed instead.
struct SpendingDonutChart: View {

    // MARK: - Environment
    @Environment(AppState.self) private var appState
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

    // MARK: - Period control (shared from parent via binding, or standalone)
    var period: SummaryPeriod = .monthly
    var targetDate: Date = .now
    var onSelectCategory: ((String) -> Void)? = nil

    // MARK: - Selection state
    @State private var selectedAngle: Double? = nil
    @State private var selectedSliceID: UUID? = nil

    private var selectedSlice: CategorySlice? {
        if let id = selectedSliceID {
            return slices.first { $0.id == id }
        }
        guard let selectedAngle else { return nil }
        var cumulative = 0.0
        for slice in slices {
            cumulative += slice.amount
            if selectedAngle <= cumulative {
                return slice
            }
        }
        return slices.last
    }

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Header
            Label("Spending by Category", systemImage: "chart.pie.fill")
                .font(.headline)
                .foregroundStyle(.primary)

            if slices.isEmpty {
                emptyState
            } else {
                chartContent
                legend
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Chart

    private var chartContent: some View {
        ZStack {
            Chart(slices) { slice in
                SectorMark(
                    angle: .value("Amount", slice.amount),
                    innerRadius: .ratio(0.55),
                    angularInset: 2
                )
                .foregroundStyle(Color(hex: slice.colorHex))
                .opacity(selectedSlice == nil || selectedSlice?.id == slice.id ? 1 : 0.35)
                .cornerRadius(4)
            }
            .frame(height: 220)
            .chartAngleSelection(value: $selectedAngle)
            .onChange(of: selectedAngle) { _, newAngle in
                if newAngle != nil {
                    selectedSliceID = nil
                }
            }

            // Centre label
            VStack(spacing: 3) {
                if let sel = selectedSlice {
                    Text(sel.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(sel.amount.currencyString(code: currency))
                        .font(.title3.weight(.bold))
                    Text(sel.percentage.percentageString)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if onSelectCategory != nil {
                        Button {
                            onSelectCategory?(sel.name)
                        } label: {
                            HStack(spacing: 2) {
                                Text("View All")
                                Image(systemName: "chevron.right")
                            }
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.08))
                            .clipShape(Capsule())
                        }
                        .padding(.top, 2)
                    }
                } else {
                    Text("Total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(totalExpense.currencyString(code: currency))
                        .font(.title3.weight(.bold))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            }
            .padding(8)
        }
    }

    // MARK: - Legend

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(slices) { slice in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: slice.colorHex))
                        .frame(width: 12, height: 12)
                    Text(slice.name)
                        .font(.subheadline)
                    Spacer()
                    Text(slice.amount.currencyString(code: currency))
                        .font(.subheadline.weight(.medium))
                    Text("(\(slice.percentage.percentageString))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if onSelectCategory != nil {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if let onSelect = onSelectCategory {
                        onSelect(slice.name)
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedAngle = nil
                            selectedSliceID = (selectedSliceID == slice.id) ? nil : slice.id
                        }
                    }
                }
                .accessibilityIdentifier("legendRow_\(slice.id)")
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.pie")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No expense data")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Data helpers

    private var currency: String { appState.selectedLedger?.currency ?? "USD" }

    private var periodTransactions: [Transaction] {
        guard let l = appState.selectedLedger else { return [] }
        return allTransactions.filter { txn in
            guard txn.ledger?.id == l.id, txn.type == .expense else { return false }
            return period == .monthly
                ? txn.date.isSameMonth(as: targetDate)
                : txn.date.isSameWeek(as: targetDate)
        }
    }

    private var totalExpense: Double {
        periodTransactions.reduce(0) { $0 + $1.amount }
    }

    private var slices: [CategorySlice] {
        // Group by category name (use "Uncategorised" as fallback)
        var groups: [String: (amount: Double, colorHex: String)] = [:]
        for txn in periodTransactions {
            let key   = txn.category?.name ?? "Uncategorised"
            let color = txn.category?.colorHex ?? "#A0A0A0"
            groups[key, default: (0, color)].amount += txn.amount
        }
        let total = groups.values.reduce(0) { $0 + $1.amount }
        return groups
            .map { name, val in
                CategorySlice(
                    name: name,
                    amount: val.amount,
                    colorHex: val.colorHex,
                    percentage: total > 0 ? val.amount / total : 0
                )
            }
            .sorted { $0.amount > $1.amount }
    }
}

// MARK: - Data Model

struct CategorySlice: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let amount: Double
    let colorHex: String
    let percentage: Double      // 0.0 … 1.0
}
