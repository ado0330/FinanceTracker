import SwiftUI
import SwiftData

/// View for computing member balances and displaying the optimal debt simplification settlement plan.
struct SettlementView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query(sort: \SplitMember.createdAt) private var allMembers: [SplitMember]
    @Query(sort: \SplitExpense.date) private var allExpenses: [SplitExpense]
    @Query(sort: \SplitSettlement.date, order: .reverse) private var allSettlements: [SplitSettlement]

    @State private var showSettleAllAlert = false
    @State private var settlementToConfirm: DebtTransfer?

    private var members: [SplitMember] {
        guard let group = appState.selectedSplitGroup else { return allMembers }
        return allMembers.filter { $0.group?.id == group.id }
    }

    private var expenses: [SplitExpense] {
        guard let group = appState.selectedSplitGroup else { return allExpenses }
        return allExpenses.filter { $0.group?.id == group.id }
    }

    private var settlements: [SplitSettlement] {
        guard let group = appState.selectedSplitGroup else { return allSettlements }
        return allSettlements.filter { $0.group?.id == group.id }
    }

    private var currencyCode: String {
        appState.selectedLedger?.currency ?? "MYR"
    }

    // MARK: - Computed Settlement Calculations

    private var memberSummaries: [MemberBalanceSummary] {
        DebtSimplifier.calculateMemberSummaries(
            members: members,
            expenses: expenses,
            settlements: settlements
        )
    }

    private var optimalTransfers: [DebtTransfer] {
        DebtSimplifier.simplifyDebts(summaries: memberSummaries)
    }

    // MARK: - Body

    var body: some View {
        List {
            // ── 1. Member Balances Overview (Paid vs Owed) ───────────────────
            balancesSection

            // ── 2. Optimal Settlement Plan ───────────────────────────────────
            settlementPlanSection

            // ── 3. Settlement History ────────────────────────────────────────
            settlementHistorySection
        }
        .listStyle(.insetGrouped)
        .alert("Settle All Balances?", isPresented: $showSettleAllAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Settle All", role: .destructive) {
                settleAllDebts()
            }
        } message: {
            Text("This will mark all current group expenses as settled and clear active debts.")
        }
        .alert("Confirm Payment?", isPresented: Binding(
            get: { settlementToConfirm != nil },
            set: { if !$0 { settlementToConfirm = nil } }
        )) {
            Button("Cancel", role: .cancel) {}
            Button("Record Paid") {
                if let transfer = settlementToConfirm {
                    recordPayment(transfer)
                }
            }
        } message: {
            if let transfer = settlementToConfirm {
                Text("Mark \(transfer.fromMemberName) as having paid \(transfer.amount.currencyString(code: currencyCode)) to \(transfer.toMemberName)?")
            }
        }
    }

    // MARK: - Sections

    private var balancesSection: some View {
        Section {
            if memberSummaries.isEmpty {
                Text("No member records available.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(memberSummaries) { summary in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: summary.colorHex))
                                .frame(width: 36, height: 36)
                            Image(systemName: summary.icon)
                                .font(.system(size: 15))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(summary.name)
                                .font(.body.weight(.medium))
                            HStack(spacing: 6) {
                                Text("Paid: \(summary.totalPaid.currencyString(code: currencyCode))")
                                Text("•")
                                Text("Owed: \(summary.totalOwed.currencyString(code: currencyCode))")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // Net balance pill
                        let net = summary.netBalance
                        if Swift.abs(net) < 0.01 {
                            Text("Settled")
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.primary.opacity(0.06))
                                .foregroundStyle(.secondary)
                                .clipShape(Capsule())
                        } else if net > 0 {
                            Text("+\(net.currencyString(code: currencyCode))")
                                .font(.subheadline.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.green.opacity(0.12))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())
                        } else {
                            Text("−\((-net).currencyString(code: currencyCode))")
                                .font(.subheadline.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.red.opacity(0.12))
                                .foregroundStyle(.red)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        } header: {
            Text("Member Balances (Paid vs Owed)")
        }
    }

    private var settlementPlanSection: some View {
        Section {
            if optimalTransfers.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("All Debts Settled")
                            .font(.body.weight(.semibold))
                        Text("No pending transfers required.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            } else {
                ForEach(optimalTransfers) { transfer in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(transfer.fromMemberName)
                                    .font(.body.weight(.semibold))
                                Image(systemName: "arrow.right")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                Text(transfer.toMemberName)
                                    .font(.body.weight(.semibold))
                            }

                            Text("Transfer amount: \(transfer.amount.currencyString(code: currencyCode))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            settlementToConfirm = transfer
                        } label: {
                            Text("Mark Paid")
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.primary)
                                .foregroundStyle(Color(uiColor: .systemBackground))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }

                Button(role: .destructive) {
                    showSettleAllAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Label("Settle All Expenses", systemImage: "checkmark.circle")
                            .font(.subheadline.bold())
                        Spacer()
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            HStack {
                Text("Optimal Settlement Plan")
                Spacer()
                if !optimalTransfers.isEmpty {
                    Text("\(optimalTransfers.count) transfer(s)")
                        .font(.caption2)
                        .textCase(nil)
                }
            }
        } footer: {
            Text("Debts are simplified using a greedy matching algorithm to minimize the total number of cross-transfers.")
        }
    }

    private var settlementHistorySection: some View {
        Section(header: Text("Settlement History (\(settlements.count))")) {
            if settlements.isEmpty {
                Text("No recorded settlements yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(settlements) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(item.fromMemberName)
                                    .fontWeight(.medium)
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(item.toMemberName)
                                    .fontWeight(.medium)
                            }
                            Text(item.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(item.amount.currencyString(code: currencyCode))
                            .font(.subheadline.weight(.semibold))
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            withAnimation {
                                modelContext.delete(item)
                                try? modelContext.save()
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func recordPayment(_ transfer: DebtTransfer) {
        let record = SplitSettlement(
            fromMemberID: transfer.fromMemberID,
            fromMemberName: transfer.fromMemberName,
            toMemberID: transfer.toMemberID,
            toMemberName: transfer.toMemberName,
            amount: transfer.amount,
            date: .now,
            isPaid: true,
            ledger: appState.selectedLedger,
            group: appState.selectedSplitGroup
        )
        modelContext.insert(record)
        try? modelContext.save()
        settlementToConfirm = nil
    }

    private func settleAllDebts() {
        withAnimation {
            // Mark all expenses in this ledger as settled
            for expense in expenses {
                expense.isSettled = true
            }
            try? modelContext.save()
        }
    }
}
