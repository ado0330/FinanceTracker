import SwiftUI
import SwiftData

/// The home screen of the app.
///
/// Sections (top → bottom):
/// 1. Hero balance card for the active ledger
/// 2. Monthly income / expense / net summary cards (2-column grid)
/// 3. Period toggle (Monthly / Weekly) that recalculates cards 2
/// 4. Recent transactions — last 5 entries with a "View all" link
struct DashboardView: View {

    // MARK: - Environment
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

    @State private var selectedPeriod: SummaryPeriod = .monthly
    @State private var detailTransaction: Transaction? = nil

    // MARK: - Computed helpers

    private var ledger: Ledger? { appState.selectedLedger }
    private var currency: String { ledger?.currency ?? "USD" }

    /// Transactions for the active ledger only.
    private var ledgerTransactions: [Transaction] {
        if let l = ledger {
            return allTransactions.filter { $0.ledger?.id == l.id || $0.ledger == nil }
        }
        return allTransactions
    }

    /// Period-filtered transactions.
    private var periodTransactions: [Transaction] {
        let now = Date.now
        return ledgerTransactions.filter { txn in
            switch selectedPeriod {
            case .monthly: return txn.date.isSameMonth(as: now)
            case .weekly:  return txn.date.isSameWeek(as: now)
            }
        }
    }

    private var totalIncome: Double {
        periodTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }
    private var totalExpense: Double {
        periodTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }
    private var netBalance: Double { totalIncome - totalExpense }

    /// Last 5 transactions for the "Recent" section.
    private var recentTransactions: [Transaction] {
        Array(ledgerTransactions.prefix(5))
    }

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                if isRegularWidth {
                    VStack(spacing: 24) {
                        DashboardBankAccountsSection()

                        HStack(alignment: .top, spacing: 20) {
                            VStack(spacing: 16) {
                                periodToggle
                                summaryGrid
                            }
                            .frame(maxWidth: .infinity)

                            VStack(spacing: 16) {
                                recentSection
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                } else {
                    VStack(spacing: 20) {
                        DashboardBankAccountsSection()
                        periodToggle
                        summaryGrid
                        recentSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    LedgerSwitcherView()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    SyncStatusBadge()
                }
            }
            .sheet(item: $detailTransaction) { txn in
                TransactionDetailSheet(transaction: txn) { }
            }
        }
    }

    // MARK: - Period Toggle

    private var periodToggle: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(SummaryPeriod.allCases) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("periodToggle")
    }

    // MARK: - Summary Grid (2-column)

    private var summaryGrid: some View {
        let cols = [GridItem(.flexible()), GridItem(.flexible())]
        let sub = selectedPeriod == .monthly
            ? Date.now.monthYearString
            : "This week"

        return LazyVGrid(columns: cols, spacing: 12) {
            SummaryCardView(
                title: "Income",
                amount: totalIncome,
                currencyCode: currency,
                icon: "arrow.up.circle.fill",
                tintColor: .green,
                subtitle: sub
            )
            .accessibilityIdentifier("incomeCard")

            SummaryCardView(
                title: "Expenses",
                amount: totalExpense,
                currencyCode: currency,
                icon: "arrow.down.circle.fill",
                tintColor: .red,
                subtitle: sub
            )
            .accessibilityIdentifier("expenseCard")

            // Net card spans full width
            SummaryCardView(
                title: "Net",
                amount: netBalance,
                currencyCode: currency,
                icon: "equal.circle.fill",
                tintColor: .primary,
                subtitle: sub
            )
            .gridCellColumns(2)                   // span 2 columns
            .accessibilityIdentifier("netCard")
        }
    }

    // MARK: - Recent Transactions

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent")
                    .font(.headline)
                Spacer()
                // "View all" is a tab switch — no navigation needed
                Button("View all") {
                    appState.selectedTab = .transactions
                }
                .font(.subheadline)
                .accessibilityIdentifier("viewAllButton")
            }

            if recentTransactions.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        Text("No transactions yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(recentTransactions) { txn in
                        TransactionRowView(transaction: txn)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                            .contextMenu {
                                Button {
                                    detailTransaction = txn
                                } label: {
                                    Label("View Details & Photo", systemImage: "photo.on.rectangle")
                                }
                            } preview: {
                                TransactionPreviewCard(transaction: txn)
                            }

                        if txn.id != recentTransactions.last?.id {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                )
            }
        }
        .accessibilityIdentifier("recentSection")
    }
}
