import SwiftUI
import SwiftData

/// Root view of the app. Owns the TabView and bootstraps:
///   1. First-launch data seeding (via DataSeeder)
///   2. Default ledger selection (stored in AppState)
///   3. Recurring rule processing on every cold launch (via RecurringService — T-18)
struct ContentView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var context
    @Environment(AppState.self)  private var appState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - Queries

    @Query(sort: \Ledger.createdAt) private var ledgers: [Ledger]

    // MARK: - Appearance Preference (defaults to "light")

    @AppStorage("appAppearance") private var appAppearance = "light"

    private var currentColorScheme: ColorScheme? {
        switch appAppearance {
        case "light": return .light
        case "dark": return .dark
        case "system": return nil
        default: return .light
        }
    }

    // MARK: - Body

    var body: some View {
        @Bindable var appState = appState

        Group {
            if horizontalSizeClass == .regular {
                ipadNavigationSplitView
            } else {
                iphoneTabView
            }
        }
        .tint(.primary)
        .preferredColorScheme(currentColorScheme)

        // MARK: - Global Action Sheets
        .sheet(isPresented: $appState.showAddTransactionSheet) {
            AddEditTransactionView {
                appState.showAddTransactionSheet = false
            }
        }
        .sheet(isPresented: $appState.showBackTapScanner) {
            BackTapQuickScanView()
        }

        // MARK: - Keyboard Shortcuts
        .background {
            keyboardShortcutsHandler
        }

        // MARK: - Bootstrap & Cloud Sync
        .task {
            DataSeeder.seedIfNeeded(context: context)
            DataSeeder.migrateExistingDataIfNeeded(context: context)
            DataSeeder.deduplicateAndReconcile(context: context)
            selectDefaultLedger()
            RecurringService.processOverdue(context: context)

            // Start Realtime sync and initial sync
            SyncEngine.shared.startRealtimeSync(context: context)
            await SyncEngine.shared.syncAll(context: context)
            DataSeeder.deduplicateAndReconcile(context: context)
            selectDefaultLedger()
        }
        .onReceive(NotificationCenter.default.publisher(for: SyncEngine.didCompleteCloudSyncNotification)) { _ in
            DataSeeder.deduplicateAndReconcile(context: context)
            selectDefaultLedger()
        }
        .onChange(of: ledgers) { _, _ in
            selectDefaultLedger()
        }
        .onOpenURL { url in
            handleIncomingURL(url)
        }
    }

    // MARK: - iPad Split View Layout

    private var ipadNavigationSplitView: some View {
        @Bindable var appState = appState

        let sidebarSelection = Binding<AppState.AppTab?>(
            get: { appState.selectedTab },
            set: { if let val = $0 { appState.selectedTab = val } }
        )

        return NavigationSplitView {
            List(selection: sidebarSelection) {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "banknote.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(width: 34, height: 34)
                            .background(Color.primary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("FinanceTracker")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.primary)
                            Text("iPad Edition")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        SyncStatusBadge()
                    }
                    .padding(.vertical, 4)
                }

                Section("Navigation") {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                        .tag(AppState.AppTab.dashboard)
                    Label("Transactions", systemImage: "list.bullet.rectangle.fill")
                        .tag(AppState.AppTab.transactions)
                    Label("Charts & Analytics", systemImage: "chart.pie.fill")
                        .tag(AppState.AppTab.charts)
                    Label("Expense Splitter", systemImage: "person.2.fill")
                        .tag(AppState.AppTab.splitter)
                    Label("Budgets", systemImage: "dial.medium.fill")
                        .tag(AppState.AppTab.budgets)
                    Label("Settings", systemImage: "gear")
                        .tag(AppState.AppTab.settings)
                }

                Section {
                    Button {
                        appState.showAddTransactionSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.subheadline.weight(.semibold))
                            Text("New Transaction")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("⌘N")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.primary)
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("FinanceTracker")
        } detail: {
            detailViewForSelectedTab
        }
    }

    // MARK: - iPhone Tab View Layout

    private var iphoneTabView: some View {
        @Bindable var appState = appState

        return TabView(selection: $appState.selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(AppState.AppTab.dashboard)

            TransactionListView()
                .tabItem {
                    Label("Transactions", systemImage: "list.bullet.rectangle.fill")
                }
                .tag(AppState.AppTab.transactions)

            ChartsView()
                .tabItem {
                    Label("Charts", systemImage: "chart.pie.fill")
                }
                .tag(AppState.AppTab.charts)

            SplitterMainView()
                .tabItem {
                    Label("Splitter", systemImage: "person.2.fill")
                }
                .tag(AppState.AppTab.splitter)

            BudgetListView()
                .tabItem {
                    Label("Budgets", systemImage: "dial.medium.fill")
                }
                .tag(AppState.AppTab.budgets)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(AppState.AppTab.settings)
        }
    }

    // MARK: - Detail View Router

    @ViewBuilder
    private var detailViewForSelectedTab: some View {
        switch appState.selectedTab {
        case .dashboard:
            DashboardView()
        case .transactions:
            TransactionListView()
        case .charts:
            ChartsView()
        case .splitter:
            SplitterMainView()
        case .budgets:
            BudgetListView()
        case .settings:
            SettingsView()
        }
    }

    // MARK: - Keyboard Shortcuts Handler

    private var keyboardShortcutsHandler: some View {
        Group {
            Button("") { appState.showAddTransactionSheet = true }
                .keyboardShortcut("n", modifiers: .command)
            Button("") { appState.selectedTab = .dashboard }
                .keyboardShortcut("1", modifiers: .command)
            Button("") { appState.selectedTab = .transactions }
                .keyboardShortcut("2", modifiers: .command)
            Button("") { appState.selectedTab = .charts }
                .keyboardShortcut("3", modifiers: .command)
            Button("") { appState.selectedTab = .splitter }
                .keyboardShortcut("4", modifiers: .command)
            Button("") { appState.selectedTab = .budgets }
                .keyboardShortcut("5", modifiers: .command)
            Button("") { appState.selectedTab = .settings }
                .keyboardShortcut("6", modifiers: .command)
        }
        .opacity(0)
        .allowsHitTesting(false)
    }

    // MARK: - Helpers

    private func handleIncomingURL(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(), scheme == "financetracker" else { return }

        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()

        if host == "backtap" || host == "quick-scan" || host == "scan" || path.contains("backtap") || path.contains("scan") {
            appState.showBackTapScanner = true
        }
    }

    private func selectDefaultLedger() {
        // If current selection is still in ledgers and has transactions, keep it
        if let current = appState.selectedLedger,
           let fresh = ledgers.first(where: { $0.id == current.id }),
           !fresh.transactions.isEmpty {
            appState.selectedLedger = fresh
            return
        }

        // Prefer ledger that contains transactions, then default, then first available
        if let ledgerWithTx = ledgers.first(where: { !$0.transactions.isEmpty }) {
            appState.selectedLedger = ledgerWithTx
        } else if let defaultLedger = ledgers.first(where: { $0.isDefault }) {
            appState.selectedLedger = defaultLedger
        } else {
            appState.selectedLedger = ledgers.first
        }
    }
}
