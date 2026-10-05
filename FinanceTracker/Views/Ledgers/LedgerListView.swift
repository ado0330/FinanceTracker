import SwiftUI
import SwiftData

/// Shows all ledgers in a card-based list.
/// Tapping a row switches the active ledger in `AppState`.
/// A ★ badge marks the default ledger.
struct LedgerListView: View {

    // MARK: - Environment & Query
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query(sort: \Ledger.createdAt) private var ledgers: [Ledger]

    // MARK: - UI State
    @State private var showingAddEdit = false
    @State private var editingLedger: Ledger? = nil

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
            if ledgers.isEmpty {
                emptyState
            } else {
                ledgerList
            }
        }
        .navigationTitle("Ledgers")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    editingLedger = nil
                    showingAddEdit = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("addLedgerButton")
            }
        }
        .sheet(isPresented: $showingAddEdit) {
            AddEditLedgerView(ledger: $editingLedger) {
                showingAddEdit = false
            }
        }
    }

    // MARK: - Subviews

    private var ledgerList: some View {
        List {
            ForEach(ledgers) { ledger in
                ledgerRow(ledger)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .listStyle(.insetGrouped)
    }

    private func ledgerRow(_ ledger: Ledger) -> some View {
        HStack(spacing: 14) {

            // Icon badge
            Image(systemName: ledger.icon)
                .foregroundStyle(.white)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 40, height: 40)
                .background(Color(hex: ledger.colorHex))
                .clipShape(Circle())
                .accessibilityIdentifier("ledgerIcon_\(ledger.id)")

            // Name + currency
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(ledger.name)
                        .font(.subheadline.weight(.semibold))
                    if ledger.isDefault {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }
                Text(ledger.currency)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Balance
            VStack(alignment: .trailing, spacing: 2) {
                Text(ledger.balance.currencyString(code: ledger.currency))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ledger.balance >= 0 ? Color(.systemGreen) : Color(.systemRed))
                Text("balance")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            appState.selectedLedger = ledger
        }
        .background(
            // Highlight the currently active ledger
            RoundedRectangle(cornerRadius: 10)
                .fill(appState.selectedLedger?.id == ledger.id
                      ? Color.primary.opacity(0.08)
                      : Color.clear)
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // Edit action
            Button {
                editingLedger = ledger
                showingAddEdit = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.orange)
            .accessibilityIdentifier("editLedger_\(ledger.id)")

            // Delete — prevent deleting the last ledger
            if ledgers.count > 1 {
                Button(role: .destructive) {
                    withAnimation { deleteLedger(ledger) }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .accessibilityIdentifier("deleteLedger_\(ledger.id)")
            }
        }
        .swipeActions(edge: .leading) {
            // Make default
            if !ledger.isDefault {
                Button {
                    makeDefault(ledger)
                } label: {
                    Label("Make Default", systemImage: "star")
                }
                .tint(.yellow)
                .accessibilityIdentifier("makeDefault_\(ledger.id)")
            }
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "creditcard",
            title: "No ledgers yet",
            message: "Create accounts or separate budgets by adding your first ledger.",
            buttonTitle: "Create Ledger"
        ) {
            editingLedger = nil
            showingAddEdit = true
        }
        .accessibilityIdentifier("emptyLedgersView")
    }

    // MARK: - Actions

    private func deleteLedger(_ ledger: Ledger) {
        // If deleting the selected ledger, switch to another one.
        if appState.selectedLedger?.id == ledger.id {
            appState.selectedLedger = ledgers.first { $0.id != ledger.id }
        }
        modelContext.delete(ledger)
        try? modelContext.save()
    }

    private func makeDefault(_ ledger: Ledger) {
        // Clear current default
        ledgers.forEach { $0.isDefault = false }
        ledger.isDefault = true
        try? modelContext.save()
    }
}
