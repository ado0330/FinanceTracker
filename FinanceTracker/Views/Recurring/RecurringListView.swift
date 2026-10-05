import SwiftUI
import SwiftData

/// Shows all recurring rules for the active ledger.
///
/// Each row displays:
///   - Category icon + name (or note fallback)
///   - Frequency badge + next due date
///   - Amount with sign colour
///   - Active / paused state via swipe leading action
/// Swipe trailing deletes the rule.
struct RecurringListView: View {

    // MARK: - Environment
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self)  private var appState

    @Query(sort: \RecurringRule.nextDueDate) private var allRules: [RecurringRule]

    // MARK: - UI State
    @State private var showingAddEdit = false
    @State private var editingRule: RecurringRule? = nil

    var isEmbedded: Bool = false

    // MARK: - Body
    var body: some View {
        if isEmbedded {
            mainContent
        } else {
            NavigationStack {
                mainContent
            }
        }
    }

    private var mainContent: some View {
        Group {
            if ledgerRules.isEmpty {
                emptyState
            } else {
                ruleList
            }
        }
        .navigationTitle("Recurring")
        .toolbar {
            if !isEmbedded {
                ToolbarItem(placement: .principal) {
                    LedgerSwitcherView()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    editingRule = nil
                    showingAddEdit = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("addRecurringButton")
            }
        }
        .sheet(isPresented: $showingAddEdit) {
            AddEditRecurringView(rule: $editingRule) {
                showingAddEdit = false
            }
        }
    }

    // MARK: - Subviews

    private var ruleList: some View {
        List {
            // Active rules first, then paused
            let active = ledgerRules.filter { $0.isActive }
            let paused = ledgerRules.filter { !$0.isActive }

            if !active.isEmpty {
                Section(header: Text("Active")) {
                    ForEach(active) { rule in ruleRow(rule) }
                }
            }
            if !paused.isEmpty {
                Section(header: Text("Paused")) {
                    ForEach(paused) { rule in ruleRow(rule) }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func ruleRow(_ rule: RecurringRule) -> some View {
        let currency = appState.selectedLedger?.currency ?? "USD"

        return HStack(spacing: 12) {

            // Icon badge
            Image(systemName: rule.category?.icon ?? "repeat")
                .foregroundStyle(.white)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(Color(hex: rule.category?.colorHex ?? "#A0A0A0"))
                .clipShape(Circle())
                .opacity(rule.isActive ? 1 : 0.5)
                .accessibilityIdentifier("ruleIcon_\(rule.id)")

            // Labels
            VStack(alignment: .leading, spacing: 3) {
                Text(rule.note.isEmpty ? (rule.category?.name ?? "Recurring") : rule.note)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(rule.isActive ? .primary : .secondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    // Frequency badge
                    Text(rule.frequency.displayName)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12), in: Capsule())

                    // Next due
                    if rule.isActive {
                        Text("Next: \(rule.nextDueDate.shortDateString)")
                            .font(.caption2)
                            .foregroundStyle(rule.isDue ? .red : .secondary)
                    } else {
                        Text("Paused")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Amount
            VStack(alignment: .trailing, spacing: 2) {
                Text(rule.amount.currencyString(code: currency))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(rule.type == .income ? Color(.systemGreen) : Color(.label))
                    .opacity(rule.isActive ? 1 : 0.5)

                if rule.isDue {
                    Text("DUE")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.red, in: Capsule())
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            editingRule = rule
            showingAddEdit = true
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation { modelContext.delete(rule) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .accessibilityIdentifier("deleteRule_\(rule.id)")
        }
        .swipeActions(edge: .leading) {
            Button {
                withAnimation { rule.isActive.toggle() }
            } label: {
                Label(rule.isActive ? "Pause" : "Resume",
                      systemImage: rule.isActive ? "pause.circle" : "play.circle")
            }
            .tint(rule.isActive ? .orange : .green)
            .accessibilityIdentifier("toggleRule_\(rule.id)")
        }
        .accessibilityIdentifier("ruleRow_\(rule.id)")
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "repeat.circle",
            title: "No recurring rules",
            message: "Set up repeating transactions like rent, salary, or subscriptions to log automatically.",
            buttonTitle: "Add Rule"
        ) {
            editingRule = nil
            showingAddEdit = true
        }
        .accessibilityIdentifier("emptyRecurringView")
    }

    // MARK: - Data helpers

    private var ledgerRules: [RecurringRule] {
        guard let l = appState.selectedLedger else { return [] }
        return allRules.filter { $0.ledger?.id == l.id }
    }
}
