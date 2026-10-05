import SwiftUI
import SwiftData

/// Detailed view for a single Account showing its card, balance breakdown,
/// reconciliation actions, and itemized transaction history.
struct AccountDetailView: View {

    @Bindable var account: Account
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - State
    @AppStorage("hideAccountBalances") private var hideAccountBalances: Bool = false
    @State private var showEditSheet = false
    @State private var showTransferSheet = false
    @State private var showReconcileAlert = false
    @State private var reconcileInputText = ""
    @State private var showDeleteConfirmation = false
    @State private var editingTransaction: Transaction? = nil

    private var sortedTransactions: [Transaction] {
        account.transactions.sorted(by: { $0.date > $1.date })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // ── Sleek Bank Card ───────────────────────────────────────
                bankCard

                // ── Quick Actions ─────────────────────────────────────────
                actionButtons

                // ── Financial Breakdown Stats ─────────────────────────────
                statsGrid

                // ── Transaction Ledger for this Account ───────────────────
                transactionsSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            hideAccountBalances.toggle()
                        }
                    } label: {
                        Image(systemName: hideAccountBalances ? "eye.slash" : "eye")
                            .font(.body)
                    }

                    Menu {
                        Button {
                            showEditSheet = true
                        } label: {
                            Label("Edit Account", systemImage: "pencil")
                        }

                        Button {
                            reconcileInputText = String(format: "%.2f", account.currentBalance)
                            showReconcileAlert = true
                        } label: {
                            Label("Reconcile Balance", systemImage: "checkmark.circle")
                        }

                        Divider()

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete Account", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.body)
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            AddEditAccountView(accountToEdit: account)
        }
        .sheet(isPresented: $showTransferSheet) {
            TransferFundsSheet()
        }
        .sheet(item: $editingTransaction) { txn in
            AddEditTransactionView(
                transaction: Binding(
                    get: { txn },
                    set: { if let updated = $0 { editingTransaction = updated } }
                ),
                onDismiss: { editingTransaction = nil }
            )
        }
        .alert("Reconcile Balance", isPresented: $showReconcileAlert) {
            TextField("New Balance", text: $reconcileInputText)
                .keyboardType(.decimalPad)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                if let newAmount = Double(reconcileInputText.replacingOccurrences(of: ",", with: ".")) {
                    account.reconcile(to: newAmount)
                    try? modelContext.save()
                }
            }
        } message: {
            Text("Enter your actual bank statement balance to reconcile this account without creating dummy transactions.")
        }
        .confirmationDialog(
            "Delete \(account.name)?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                modelContext.delete(account)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove the account. Associated transactions will remain in your ledger as unassigned.")
        }
    }

    // MARK: - Bank Card
    private var bankCard: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: account.colorHex),
                            Color(hex: account.colorHex).opacity(0.85)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
                .frame(height: 180)

            // Watermark Icon
            Image(systemName: account.icon)
                .font(.system(size: 110, weight: .bold))
                .foregroundStyle(.white.opacity(0.08))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 16)
                .padding(.trailing, 20)
                .clipped()

            // Card details
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(account.institution.isEmpty ? account.accountType.displayName.uppercased() : account.institution.uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.8))

                    Spacer()

                    if !account.accountNumberLast4.isEmpty {
                        Text(account.maskedNumberDisplay)
                            .font(.subheadline.monospaced())
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                Spacer()

                Text(account.name)
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(alignment: .firstTextBaseline) {
                    Text(hideAccountBalances ? "••••••" : account.currentBalance.currencyString(code: account.currency))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()

                    Text(account.accountType.displayName)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.2))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
            .padding(20)
        }
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                reconcileInputText = String(format: "%.2f", account.currentBalance)
                showReconcileAlert = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Reconcile")
                }
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemGroupedBackground))
                .foregroundStyle(Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Button {
                showTransferSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left.arrow.right")
                    Text("Transfer")
                }
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemGroupedBackground))
                .foregroundStyle(Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Stats Grid
    private var statsGrid: some View {
        HStack(spacing: 12) {
            statCard(
                title: "Starting",
                value: account.initialBalance.currencyString(code: account.currency),
                icon: "flag.fill",
                color: Color.secondary
            )

            statCard(
                title: "Total Inflow",
                value: "+\(account.totalIncome.currencyString(code: account.currency))",
                icon: "arrow.down.left",
                color: Color(.systemGreen)
            )

            statCard(
                title: "Total Outflow",
                value: "−\(account.totalExpense.currencyString(code: account.currency))",
                icon: "arrow.up.right",
                color: Color.primary
            )
        }
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(hideAccountBalances ? "••••••" : value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Transactions Section
    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Transactions")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(sortedTransactions.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if sortedTransactions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary.opacity(0.6))
                        .padding(.top, 20)

                    Text("No transactions yet")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    Text("Transactions attributed to \(account.name) will appear here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 20)
                }
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(sortedTransactions) { txn in
                        TransactionRowView(transaction: txn)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingTransaction = txn
                            }
                            .contextMenu {
                                Button {
                                    editingTransaction = txn
                                } label: {
                                    Label("Edit Transaction", systemImage: "pencil")
                                }
                            } preview: {
                                TransactionPreviewCard(transaction: txn)
                            }

                        if txn.id != sortedTransactions.last?.id {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
            }
        }
    }
}
