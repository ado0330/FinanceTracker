import SwiftUI
import SwiftData

/// Shows all budgets for the active ledger with a progress bar for each.
///
/// - Green bar: under 75% spent
/// - Orange bar: 75–99% spent (warning zone)
/// - Red bar: over budget
/// - Swipe-to-delete removes a budget; swipe-leading toggles isActive.
struct BudgetListView: View {

    // MARK: - Environment
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query(sort: \Budget.createdAt) private var allBudgets: [Budget]
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

    // MARK: - UI State
    @State private var showingAddEdit = false
    @State private var editingBudget: Budget? = nil

    // MARK: - Body
    var body: some View {
        NavigationStack {
            Group {
                if ledgerBudgets.isEmpty {
                    emptyState
                } else {
                    budgetList
                }
            }
            .navigationTitle("Budgets")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    LedgerSwitcherView()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        editingBudget = nil
                        showingAddEdit = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("addBudgetButton")
                }
            }
            .sheet(isPresented: $showingAddEdit) {
                AddEditBudgetView(budget: $editingBudget) {
                    showingAddEdit = false
                }
            }
        }
    }

    // MARK: - Subviews

    private var budgetList: some View {
        List {
            ForEach(ledgerBudgets) { budget in
                budgetRow(budget)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            }
        }
        .listStyle(.insetGrouped)
    }

    private func budgetRow(_ budget: Budget) -> some View {
        let spent    = budget.spentAmount(in: ledgerTransactions)
        let progress = budget.progressRatio(in: ledgerTransactions)
        let isOver   = budget.isOverBudget(in: ledgerTransactions)
        let currency = appState.selectedLedger?.currency ?? "USD"

        let barColor: Color = {
            if isOver            { return .red }
            if progress >= 0.75  { return .orange }
            return .green
        }()

        return VStack(alignment: .leading, spacing: 10) {

            // ── Category + period badge ───────────────────────────────
            HStack {
                if let cat = budget.category {
                    Image(systemName: cat.icon)
                        .foregroundStyle(.white)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 30, height: 30)
                        .background(Color(hex: cat.colorHex))
                        .clipShape(Circle())
                    Text(cat.name)
                        .font(.subheadline.weight(.semibold))
                } else {
                    Image(systemName: "tag.slash")
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                    Text("No category")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Period badge
                Text(budget.period.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12), in: Capsule())

                // Active toggle indicator
                if !budget.isActive {
                    Image(systemName: "pause.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }

            // ── Progress bar ─────────────────────────────────────────
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor.opacity(0.15))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: geo.size.width * progress, height: 8)
                        .animation(.easeOut(duration: 0.4), value: progress)
                }
            }
            .frame(height: 8)

            // ── Amount labels ─────────────────────────────────────────
            HStack {
                Text(spent.currencyString(code: currency) + " spent")
                    .font(.caption)
                    .foregroundStyle(isOver ? .red : .secondary)
                Spacer()
                if isOver {
                    Text("Over by " + (spent - budget.amount).currencyString(code: currency))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                } else {
                    Text(budget.remainingAmount(in: ledgerTransactions).currencyString(code: currency) + " left of " + budget.amount.currencyString(code: currency))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(budget.isActive ? 1 : 0.5)
        .contentShape(Rectangle())
        .onTapGesture {
            editingBudget = budget
            showingAddEdit = true
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation { modelContext.delete(budget) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .accessibilityIdentifier("deleteBudget_\(budget.id)")
        }
        .swipeActions(edge: .leading) {
            Button {
                withAnimation { budget.isActive.toggle() }
            } label: {
                Label(budget.isActive ? "Pause" : "Resume",
                      systemImage: budget.isActive ? "pause.circle" : "play.circle")
            }
            .tint(budget.isActive ? .orange : .green)
            .accessibilityIdentifier("toggleBudget_\(budget.id)")
        }
        .accessibilityIdentifier("budgetRow_\(budget.id)")
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "dial.medium",
            title: "No budgets yet",
            message: "Set a spending limit for a category to keep your expenses on track.",
            buttonTitle: "Create Budget"
        ) {
            editingBudget = nil
            showingAddEdit = true
        }
        .accessibilityIdentifier("emptyBudgetsView")
    }

    // MARK: - Data helpers

    private var ledgerBudgets: [Budget] {
        guard let l = appState.selectedLedger else { return [] }
        return allBudgets.filter { $0.ledger?.id == l.id }
    }

    private var ledgerTransactions: [Transaction] {
        guard let l = appState.selectedLedger else { return [] }
        return allTransactions.filter { $0.ledger?.id == l.id }
    }
}
