import SwiftUI
import SwiftData

/// Comprehensive Accounts & Net Worth Hub.
/// Allows the user to view all bank accounts, know their total bank account money,
/// filter by account type, reconcile balances, and transfer funds.
struct AccountsHubView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @Query(filter: #Predicate<Account> { !$0.isArchived }, sort: \Account.createdAt)
    private var allAccounts: [Account]

    // MARK: - State
    @AppStorage("hideAccountBalances") private var hideAccountBalances: Bool = false
    @State private var selectedFilter: AccountFilter = .all
    @State private var showAddAccountSheet = false
    @State private var showTransferSheet = false
    @State private var selectedAccountForDetail: Account? = nil

    private enum AccountFilter: String, CaseIterable, Identifiable {
        case all        = "All"
        case bank       = "Banks"
        case savings    = "Savings"
        case creditCard = "Cards"
        case cash       = "Cash & Wallets"

        var id: String { rawValue }
    }

    // MARK: - Computed Balances

    private var currencyCode: String {
        appState.selectedLedger?.currency ?? allAccounts.first?.currency ?? "MYR"
    }

    /// Total money in bank accounts (checking + savings)
    private var totalBankMoney: Double {
        allAccounts
            .filter { $0.accountType == .bank || $0.accountType == .savings }
            .reduce(0) { $0 + $1.currentBalance }
    }

    /// Total money in cash & e-wallets
    private var totalCashMoney: Double {
        allAccounts
            .filter { $0.accountType == .cash || $0.accountType == .eWallet }
            .reduce(0) { $0 + $1.currentBalance }
    }

    /// Total outstanding credit card debt / liabilities
    private var totalCreditDebt: Double {
        allAccounts
            .filter { $0.accountType == .creditCard }
            .reduce(0) { $0 + $1.currentBalance }
    }

    /// Net Total Money across all assets minus liabilities
    private var totalNetMoney: Double {
        let assets = allAccounts
            .filter { $0.accountType.isAsset }
            .reduce(0) { $0 + $1.currentBalance }
        return assets - totalCreditDebt
    }

    private var filteredAccounts: [Account] {
        switch selectedFilter {
        case .all:
            return allAccounts
        case .bank:
            return allAccounts.filter { $0.accountType == .bank }
        case .savings:
            return allAccounts.filter { $0.accountType == .savings }
        case .creditCard:
            return allAccounts.filter { $0.accountType == .creditCard }
        case .cash:
            return allAccounts.filter { $0.accountType == .cash || $0.accountType == .eWallet }
        }
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // ── Executive Total Money Overview ────────────────────
                    executiveOverviewCard

                    // ── Quick Actions ─────────────────────────────────────
                    quickActionsBar

                    // ── Filter Segment ────────────────────────────────────
                    filterPills

                    // ── Accounts List ─────────────────────────────────────
                    accountsSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Bank Accounts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                hideAccountBalances.toggle()
                            }
                        } label: {
                            Image(systemName: hideAccountBalances ? "eye.slash" : "eye")
                                .font(.system(size: 15))
                        }

                        Button {
                            showAddAccountSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddAccountSheet) {
                AddEditAccountView()
            }
            .sheet(isPresented: $showTransferSheet) {
                TransferFundsSheet()
            }
            .navigationDestination(item: $selectedAccountForDetail) { account in
                AccountDetailView(account: account)
            }
        }
    }

    // MARK: - Executive Overview Card
    private var executiveOverviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOTAL BANK MONEY")
                        .font(.caption2.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(.secondary)

                    Text(hideAccountBalances ? "••••••" : totalBankMoney.currencyString(code: currencyCode))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Net Worth")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(hideAccountBalances ? "••••••" : totalNetMoney.currencyString(code: currencyCode))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(totalNetMoney >= 0 ? Color.primary : Color.red)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Divider()

            // Sub-metrics
            HStack(spacing: 12) {
                subMetric(
                    label: "Bank Accounts",
                    value: totalBankMoney.currencyString(code: currencyCode),
                    icon: "building.columns.fill"
                )

                subMetric(
                    label: "Cash & Wallets",
                    value: totalCashMoney.currencyString(code: currencyCode),
                    icon: "banknote.fill"
                )

                subMetric(
                    label: "Credit Debt",
                    value: totalCreditDebt > 0 ? "−\(totalCreditDebt.currencyString(code: currencyCode))" : "RM 0.00",
                    icon: "creditcard.fill",
                    valueColor: totalCreditDebt > 0 ? Color.red : Color.secondary
                )
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private func subMetric(label: String, value: String, icon: String, valueColor: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(hideAccountBalances ? "••••••" : value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Quick Actions Bar
    private var quickActionsBar: some View {
        HStack(spacing: 12) {
            Button {
                showAddAccountSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Account")
                }
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Color.primary)
                .foregroundStyle(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            Button {
                showTransferSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left.arrow.right")
                    Text("Transfer Funds")
                }
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Color(.secondarySystemGroupedBackground))
                .foregroundStyle(Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(allAccounts.count < 2)
        }
    }

    // MARK: - Filter Pills
    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AccountFilter.allCases) { filter in
                    let isSelected = selectedFilter == filter
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
                    } label: {
                        Text(filter.rawValue)
                            .font(.caption.weight(isSelected ? .semibold : .medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isSelected ? Color.primary : Color(.secondarySystemGroupedBackground))
                            .foregroundStyle(isSelected ? Color(.systemBackground) : Color.primary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? Color.clear : Color.primary.opacity(0.12), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Accounts Section
    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(selectedFilter.rawValue) (\(filteredAccounts.count))")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()
            }

            if filteredAccounts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "building.columns")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary.opacity(0.6))
                        .padding(.top, 24)

                    Text(allAccounts.isEmpty ? "No Bank Accounts Added" : "No \(selectedFilter.rawValue) Found")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(allAccounts.isEmpty ? "Add your bank account, savings, or cards to track your total money in one place." : "Try selecting a different filter above.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    if allAccounts.isEmpty {
                        Button {
                            showAddAccountSheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                Text("Add Bank Account")
                            }
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.primary)
                            .foregroundStyle(Color(.systemBackground))
                            .clipShape(Capsule())
                        }
                        .padding(.top, 4)
                        .padding(.bottom, 24)
                    } else {
                        Spacer().frame(height: 12)
                    }
                }
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredAccounts) { account in
                        accountRowCard(account)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedAccountForDetail = account
                            }
                    }
                }
            }
        }
    }

    private func accountRowCard(_ account: Account) -> some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(hex: account.colorHex))
                    .frame(width: 44, height: 44)

                Image(systemName: account.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(account.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)

                    if account.isDefault {
                        Text("Default")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.1))
                            .foregroundStyle(Color.primary)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 6) {
                    if !account.institution.isEmpty {
                        Text(account.institution)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !account.accountNumberLast4.isEmpty {
                        Text(account.maskedNumberDisplay)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Balance
            VStack(alignment: .trailing, spacing: 3) {
                Text(hideAccountBalances ? "••••••" : account.currentBalance.currencyString(code: account.currency))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(account.accountType == .creditCard && account.currentBalance > 0 ? Color.red : Color.primary)

                Text(account.accountType.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.secondary.opacity(0.6))
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
