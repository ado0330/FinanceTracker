import SwiftUI
import SwiftData

/// Apple Wallet-style bank cards carousel and Total Bank Money executive card
/// embedded directly into the Dashboard.
struct DashboardBankAccountsSection: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query(filter: #Predicate<Account> { !$0.isArchived }, sort: \Account.createdAt)
    private var allAccounts: [Account]

    // MARK: - State
    @AppStorage("hideAccountBalances") private var hideAccountBalances: Bool = false
    @State private var showAccountsHub = false
    @State private var showAddAccountSheet = false
    @State private var selectedAccountForDetail: Account? = nil

    private var currencyCode: String {
        appState.selectedLedger?.currency ?? allAccounts.first?.currency ?? "MYR"
    }

    /// Total liquid money in bank accounts (checking + savings)
    private var totalBankMoney: Double {
        allAccounts
            .filter { $0.accountType == .bank || $0.accountType == .savings }
            .reduce(0) { $0 + $1.currentBalance }
    }

    /// Total net money across all accounts (assets minus liabilities)
    private var totalNetMoney: Double {
        let assets = allAccounts.filter { $0.accountType.isAsset }.reduce(0) { $0 + $1.currentBalance }
        let liabilities = allAccounts.filter { !$0.accountType.isAsset }.reduce(0) { $0 + $1.currentBalance }
        return assets - liabilities
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // ── Section Header ────────────────────────────────────────────
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bank Accounts & Money")
                        .font(.headline)
                        .foregroundStyle(Color.primary)

                    if !allAccounts.isEmpty {
                        Text("Total Bank Money: \(hideAccountBalances ? "••••••" : totalBankMoney.currencyString(code: currencyCode))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            hideAccountBalances.toggle()
                        }
                    } label: {
                        Image(systemName: hideAccountBalances ? "eye.slash" : "eye")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.primary)
                            .frame(width: 28, height: 28)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("hideBalancesButton")

                    Button {
                        showAddAccountSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.primary)
                            .frame(width: 28, height: 28)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        showAccountsHub = true
                    } label: {
                        Text("See All")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.primary)
                    }
                }
            }

            // ── Content: Cards or Empty State ─────────────────────────────
            if allAccounts.isEmpty {
                emptyOnboardingCard
            } else {
                bankCardsCarousel
            }
        }
        .sheet(isPresented: $showAccountsHub) {
            AccountsHubView()
        }
        .sheet(isPresented: $showAddAccountSheet) {
            AddEditAccountView()
        }
        .sheet(item: $selectedAccountForDetail) { acc in
            NavigationStack {
                AccountDetailView(account: acc)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Done") { selectedAccountForDetail = nil }
                        }
                    }
            }
        }
    }

    // MARK: - Bank Cards Carousel
    private var bankCardsCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(allAccounts) { account in
                    bankCardView(account)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedAccountForDetail = account
                        }
                }

                // Add Card Button
                addCardButton
            }
            .padding(.vertical, 4)
        }
    }

    private func bankCardView(_ account: Account) -> some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 18)
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
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                .frame(width: 220, height: 125)

            // Watermark icon
            Image(systemName: account.icon)
                .font(.system(size: 72, weight: .bold))
                .foregroundStyle(.white.opacity(0.08))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 8)
                .padding(.trailing, 10)
                .clipped()

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(account.institution.isEmpty ? account.accountType.displayName.uppercased() : account.institution.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.0)
                        .foregroundStyle(.white.opacity(0.8))

                    Spacer()

                    if !account.accountNumberLast4.isEmpty {
                        Text("•••• \(account.accountNumberLast4)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                Spacer()

                Text(account.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(hideAccountBalances ? "••••••" : account.currentBalance.currencyString(code: account.currency))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(14)
        }
        .frame(width: 220, height: 125)
    }

    private var addCardButton: some View {
        Button {
            showAddAccountSheet = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)

                Text("Add Account")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 120, height: 125)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.primary.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty Onboarding Card
    private var emptyOnboardingCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 44, height: 44)

                Image(systemName: "building.columns.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Track Your Bank Accounts")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)

                Text("Add your accounts to see total money and real balances.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                showAddAccountSheet = true
            } label: {
                Text("Add")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.primary)
                    .foregroundStyle(Color(.systemBackground))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}
