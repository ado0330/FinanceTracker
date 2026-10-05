import SwiftUI
import SwiftData

/// View displaying the history of split expenses for the active group/ledger.
struct SplitExpenseListView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query(sort: \SplitExpense.date, order: .reverse) private var allExpenses: [SplitExpense]
    @Query(sort: \SplitMember.createdAt) private var allMembers: [SplitMember]

    @State private var showAddExpense = false
    @State private var expenseToEdit: SplitExpense?
    @State private var selectedFilter: FilterOption = .unsettled

    enum FilterOption: String, CaseIterable {
        case unsettled = "Unsettled"
        case all = "All"
        case settled = "Settled"
    }

    private var members: [SplitMember] {
        guard let group = appState.selectedSplitGroup else { return allMembers }
        return allMembers.filter { $0.group?.id == group.id }
    }

    private var expenses: [SplitExpense] {
        guard let group = appState.selectedSplitGroup else { return allExpenses }
        let groupExpenses = allExpenses.filter { $0.group?.id == group.id }
        switch selectedFilter {
        case .unsettled: return groupExpenses.filter { !$0.isSettled }
        case .settled:   return groupExpenses.filter { $0.isSettled }
        case .all:       return groupExpenses
        }
    }

    private var currencyCode: String {
        appState.selectedLedger?.currency ?? "MYR"
    }

    private var currentUser: SplitMember? {
        members.first(where: { $0.isCurrentUser }) ?? members.first
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Top Summary Card ─────────────────────────────────────────────
            summaryHeader

            // ── Filter Picker ────────────────────────────────────────────────
            Picker("Filter", selection: $selectedFilter) {
                ForEach(FilterOption.allCases, id: \.self) { opt in
                    Text(opt.rawValue).tag(opt)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            // ── Expense List ─────────────────────────────────────────────────
            if expenses.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(expenses) { expense in
                        expenseRow(expense)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                expenseToEdit = expense
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    withAnimation {
                                        expense.isSettled.toggle()
                                        try? modelContext.save()
                                    }
                                } label: {
                                    Label(expense.isSettled ? "Reopen" : "Settle", systemImage: expense.isSettled ? "arrow.uturn.backward" : "checkmark")
                                }
                                .tint(expense.isSettled ? .orange : .green)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteExpense(expense)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteExpense(expense)
                                } label: {
                                    Label("Delete Expense", systemImage: "trash")
                                }
                                Button {
                                    withAnimation {
                                        expense.isSettled.toggle()
                                        try? modelContext.save()
                                    }
                                } label: {
                                    Label(expense.isSettled ? "Reopen Expense" : "Mark as Settled", systemImage: expense.isSettled ? "arrow.uturn.backward" : "checkmark")
                                }
                            }
                    }
                    .onDelete(perform: deleteExpenses)
                }
                .listStyle(.insetGrouped)
            }
        }
        .sheet(isPresented: $showAddExpense) {
            AddEditSplitExpenseView(expenseToEdit: nil)
        }
        .sheet(item: $expenseToEdit) { expense in
            AddEditSplitExpenseView(expenseToEdit: expense)
        }
    }

    // MARK: - Subviews

    private var summaryHeader: some View {
        let unsettled = allExpenses.filter {
            !$0.isSettled && (appState.selectedSplitGroup == nil || $0.group?.id == appState.selectedSplitGroup?.id)
        }
        let totalGroupSpent = unsettled.reduce(0.0) { $0 + $1.totalAmount }

        var yourShare = 0.0
        var yourPaid = 0.0

        if let currentUID = currentUser?.id {
            for exp in unsettled {
                for p in exp.payers where p.memberID == currentUID {
                    yourPaid += p.amount
                }
                for s in exp.shares where s.memberID == currentUID {
                    yourShare += s.amount
                }
            }
        }

        let yourNet = yourPaid - yourShare

        return VStack(spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Unsettled")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(totalGroupSpent.currencyString(code: currencyCode))
                        .font(.title2.bold())
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Your Balance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Text(yourNet >= 0 ? "+\(yourNet.currencyString(code: currencyCode))" : "−\((-yourNet).currencyString(code: currencyCode))")
                            .font(.title2.bold())
                            .foregroundStyle(yourNet >= 0 ? .green : .red)
                    }
                }
            }

            Divider()

            HStack {
                Label("You Paid: \(yourPaid.currencyString(code: currencyCode))", systemImage: "arrow.up.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Label("Your Share: \(yourShare.currencyString(code: currencyCode))", systemImage: "person.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func expenseRow(_ expense: SplitExpense) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 40, height: 40)
                Image(systemName: expense.splitMode.icon)
                    .font(.system(size: 17))
                    .foregroundStyle(.primary)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(expense.title)
                        .font(.body.weight(.medium))
                    if expense.isSettled {
                        Text("Settled")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.12))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                    if expense.receiptImageData != nil {
                        Image(systemName: "paperclip")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 6) {
                    Text(expense.date.formatted(date: .abbreviated, time: .omitted))
                    Text("•")
                    Text(payerSummaryText(for: expense))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(expense.totalAmount.currencyString(code: currencyCode))
                    .font(.body.weight(.semibold))

                if let currentUID = currentUser?.id,
                   let myShare = expense.shares.first(where: { $0.memberID == currentUID }) {
                    Text("Your share: \(myShare.amount.currencyString(code: currencyCode))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text("No Expenses Found")
                .font(.headline)
            Text("Tap the '+' button in the top bar to record your first shared expense.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func payerSummaryText(for expense: SplitExpense) -> String {
        if expense.payers.count == 1, let pID = expense.payers.first?.memberID {
            let name = members.first(where: { $0.id == pID })?.name ?? "Someone"
            return "Paid by \(name)"
        } else if expense.payers.count > 1 {
            return "\(expense.payers.count) payers"
        }
        return "Unassigned"
    }

    private func deleteExpense(_ expense: SplitExpense) {
        withAnimation {
            modelContext.delete(expense)
            try? modelContext.save()
        }
    }

    private func deleteExpenses(at offsets: IndexSet) {
        for index in offsets {
            if expenses.indices.contains(index) {
                deleteExpense(expenses[index])
            }
        }
    }
}
