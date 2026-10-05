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
        @Bindable var appState = appState   // Needed for two-way tab binding

        TabView(selection: $appState.selectedTab) {

            // ── Tab 1: Dashboard ──────────────────────────────────────────
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(AppState.AppTab.dashboard)

            // ── Tab 2: Transactions ───────────────────────────────────────
            TransactionListView()
                .tabItem {
                    Label("Transactions", systemImage: "list.bullet.rectangle.fill")
                }
                .tag(AppState.AppTab.transactions)

            // ── Tab 3: Charts ─────────────────────────────────────────────
            ChartsView()
                .tabItem {
                    Label("Charts", systemImage: "chart.pie.fill")
                }
                .tag(AppState.AppTab.charts)

            // ── Tab 4: Splitter ───────────────────────────────────────────
            SplitterMainView()
                .tabItem {
                    Label("Splitter", systemImage: "person.2.fill")
                }
                .tag(AppState.AppTab.splitter)

            // ── Tab 5: Budgets ────────────────────────────────────────────
            BudgetListView()
                .tabItem {
                    Label("Budgets", systemImage: "dial.medium.fill")
                }
                .tag(AppState.AppTab.budgets)

            // ── Tab 6: Settings ───────────────────────────────────────────
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(AppState.AppTab.settings)
        }
        .tint(.primary)
        .preferredColorScheme(currentColorScheme)

        // MARK: - Bootstrap

        // Runs once on cold launch — seeding is idempotent (no-op after first run).
        .task {
            DataSeeder.seedIfNeeded(context: context)
            DataSeeder.migrateExistingDataIfNeeded(context: context)
            selectDefaultLedger()
            RecurringService.processOverdue(context: context)
        }

        // After seeding, ledgers will be populated — pick the default one.
        .onChange(of: ledgers) { _, _ in
            selectDefaultLedger()
        }

        // MARK: - Back Tap & URL Scheme Handling
        .onOpenURL { url in
            handleIncomingURL(url)
        }
        .sheet(isPresented: $appState.showBackTapScanner) {
            BackTapQuickScanView()
        }
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
        guard appState.selectedLedger == nil else { return }
        appState.selectedLedger = ledgers.first(where: { $0.isDefault }) ?? ledgers.first
    }
}
