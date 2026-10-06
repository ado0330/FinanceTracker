import SwiftUI
import SwiftData

/// Fast, balanced transfer between two accounts.
struct TransferFundsSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @Query(filter: #Predicate<Account> { !$0.isArchived }, sort: \Account.name)
    private var accounts: [Account]

    @State private var fromAccount: Account?
    @State private var toAccount: Account?
    @State private var amountText: String = ""
    @State private var date: Date = .now
    @State private var note: String = ""
    @State private var recordInTransactions: Bool = true

    private var amountDouble: Double {
        Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0.0
    }

    private var isValid: Bool {
        guard let from = fromAccount, let to = toAccount else { return false }
        return from.id != to.id && amountDouble > 0
    }

    private var currencyCode: String {
        fromAccount?.currency ?? appState.selectedLedger?.currency ?? "MYR"
    }

    var body: some View {
        NavigationStack {
            Form {
                // ── Accounts Section ──────────────────────────────────────
                Section(header: Text("Transfer Details")) {
                    Picker("From Account", selection: $fromAccount) {
                        Text("Select Source Account").tag(Account?.none)
                        ForEach(accounts) { acc in
                            HStack {
                                Image(systemName: acc.icon)
                                Text(acc.fullDisplayName)
                            }
                            .tag(Account?.some(acc))
                        }
                    }

                    Picker("To Account", selection: $toAccount) {
                        Text("Select Target Account").tag(Account?.none)
                        ForEach(accounts) { acc in
                            HStack {
                                Image(systemName: acc.icon)
                                Text(acc.fullDisplayName)
                            }
                            .tag(Account?.some(acc))
                        }
                    }
                }

                // ── Amount & Date ─────────────────────────────────────────
                Section(header: Text("Amount & Date")) {
                    HStack {
                        Text(currencyCode)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)

                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.body.weight(.semibold))
                    }

                    DatePicker("Date", selection: $date, displayedComponents: [.date])
                }

                // ── Options ───────────────────────────────────────────────
                Section(
                    header: Text("Transaction History"),
                    footer: Text(recordInTransactions
                        ? "Inflow and outflow transactions will be logged in your ledger history."
                        : "Only account balances are updated directly. No transactions will be logged.")
                ) {
                    Toggle("Record in Transactions", isOn: $recordInTransactions)
                }

                // ── Note ──────────────────────────────────────────────────
                Section(header: Text("Note (optional)")) {
                    TextField("e.g. Monthly Savings Transfer", text: $note)
                }
            }
            .navigationTitle("Transfer Funds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Transfer") { executeTransfer() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
            .onAppear {
                if fromAccount == nil && !accounts.isEmpty {
                    fromAccount = accounts.first
                }
                if toAccount == nil && accounts.count > 1 {
                    toAccount = accounts.count > 1 ? accounts[1] : accounts.first
                }
            }
        }
    }

    private func executeTransfer() {
        guard let from = fromAccount, let to = toAccount, amountDouble > 0 else { return }

        let defaultNote = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Transfer: \(from.name) → \(to.name)"
            : note.trimmingCharacters(in: .whitespacesAndNewlines)

        if recordInTransactions {
            // 1. Outflow from source account
            let outflowTx = Transaction(
                name: "Transfer to \(to.name)",
                amount: amountDouble,
                type: .expense,
                date: date,
                note: "\(defaultNote) (Outflow)",
                ledger: appState.selectedLedger,
                category: nil,
                account: from
            )

            // 2. Inflow to target account
            let inflowTx = Transaction(
                name: "Transfer from \(from.name)",
                amount: amountDouble,
                type: .income,
                date: date,
                note: "\(defaultNote) (Inflow)",
                ledger: appState.selectedLedger,
                category: nil,
                account: to
            )

            modelContext.insert(outflowTx)
            modelContext.insert(inflowTx)
        } else {
            // Adjust balances directly without polluting transaction history
            if from.accountType == .creditCard {
                from.initialBalance += amountDouble
            } else {
                from.initialBalance -= amountDouble
            }

            if to.accountType == .creditCard {
                to.initialBalance -= amountDouble
            } else {
                to.initialBalance += amountDouble
            }
        }

        try? modelContext.save()
        dismiss()
    }
}
