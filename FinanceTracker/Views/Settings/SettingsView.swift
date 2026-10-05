import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Settings and preferences screen.
///
/// Features:
/// - Ledger management (view, create, switch default)
/// - Category & Tag management
/// - Daily budget-check reminder notifications
/// - CSV Export (via ShareLink) & CSV Import (via FileImporter)
/// - App version and sideload info
struct SettingsView: View {

    // MARK: - Environment & State
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query private var ledgers: [Ledger]
    @Query private var categories: [Category]
    @Query private var tags: [Tag]
    @Query private var recurringRules: [RecurringRule]
    @Query private var allTransactions: [Transaction]
    @Query(filter: #Predicate<Account> { !$0.isArchived }) private var accounts: [Account]

    // MARK: - Appearance Preference
    @AppStorage("appAppearance") private var appAppearance = "light"

    // MARK: - Notification Preferences
    @AppStorage("dailyReminderEnabled") private var dailyReminderEnabled = false
    @AppStorage("dailyReminderHour") private var dailyReminderHour = 20
    @AppStorage("dailyReminderMinute") private var dailyReminderMinute = 0
    @State private var reminderDate: Date = {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        comps.hour = 20
        comps.minute = 0
        return Calendar.current.date(from: comps) ?? .now
    }()


    // MARK: - Data Management State
    @State private var showFileImporter = false
    @State private var importAlertTitle = ""
    @State private var importAlertMessage = ""
    @State private var showImportAlert = false
    @State private var showResetAlert = false
    @State private var showMigrateMYRAlert = false

    // MARK: - Cloud Sync State
    @State private var syncEngine = SyncEngine.shared
    @State private var supabaseUrlInput: String = SyncEngine.shared.supabaseURL
    @State private var supabaseKeyInput: String = SyncEngine.shared.supabaseAnonKey
    @State private var showSyncSetupSheet: Bool = false

    // MARK: - Filtered Transactions
    private var ledgerTransactions: [Transaction] {
        guard let ledger = appState.selectedLedger else { return [] }
        return allTransactions.filter { $0.ledger?.id == ledger.id }
    }

    private var exportTempURL: URL? {
        guard let ledger = appState.selectedLedger else { return nil }
        let csv = CSVService.exportCSV(
            transactions: ledgerTransactions,
            currencyCode: ledger.currency
        )
        let filename = "\(ledger.name.replacingOccurrences(of: " ", with: "_"))_Export.csv"
        return CSVService.createTempCSVFile(from: csv, filename: filename)
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                cloudSyncSection
                ledgerSection
                accountsSection
                organizeSection
                notificationsSection
                geminiSection
                backTapSection
                dataSection
                aboutSection
            }
            .navigationTitle("Settings")
            .onAppear {
                if supabaseUrlInput.isEmpty && !syncEngine.supabaseURL.isEmpty {
                    supabaseUrlInput = syncEngine.supabaseURL
                }
                if supabaseKeyInput.isEmpty && !syncEngine.supabaseAnonKey.isEmpty {
                    supabaseKeyInput = syncEngine.supabaseAnonKey
                }
            }
            .sheet(isPresented: $showSyncSetupSheet) {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Setup Free iPhone & iPad Sync in 2 Minutes")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.primary)

                            Text("FinanceTracker syncs seamlessly between your iPhone and iPad using Supabase's free PostgreSQL database and Realtime WebSocket channels.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 14) {
                                stepRow(number: "1", title: "Create Free Project", description: "Sign in to supabase.com and create a new project with the free tier.")
                                stepRow(number: "2", title: "Execute Database Schema", description: "Go to SQL Editor in your Supabase dashboard, copy the contents of supabase_schema.sql from the project root, and click Run.")
                                stepRow(number: "3", title: "Copy API Credentials", description: "In Project Settings → API, copy your Project URL and anon public key. Paste them into this screen on both your iPhone and iPad.")
                            }
                            .padding(.vertical, 4)

                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.green)
                                Text("Offline-First: All transactions remain saved locally in SwiftData. Changes sync automatically in under 0.5s when online.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(20)
                    }
                    .navigationTitle("Sync Setup Guide")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showSyncSetupSheet = false
                            }
                            .font(.subheadline.bold())
                        }
                    }
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleCSVImport(result: result)
            }
            .alert(importAlertTitle, isPresented: $showImportAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importAlertMessage)
            }
            .alert("URL Copied", isPresented: $showCopiedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("URL scheme 'financetracker://backtap' copied to clipboard. Use it in Apple Shortcuts to open the scanner.")
            }
            .alert("Switch to Malaysian Ringgit (MYR)?", isPresented: $showMigrateMYRAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Switch") {
                    if let ledger = appState.selectedLedger {
                        ledger.currency = "MYR"
                        try? modelContext.save()
                    }
                }
            } message: {
                Text("This will update the active ledger's currency to MYR (RM).")
            }
            .alert("Reset to Fresh Sample Data?", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    DataSeeder.resetToFreshMYRData(context: modelContext)
                    appState.selectedLedger = ledgers.first(where: { $0.isDefault }) ?? ledgers.first
                }
            } message: {
                Text("This will erase all current records and recreate the default Malaysian Ringgit (MYR) ledger, categories, and tags.")
            }
            .onAppear {
                syncReminderDateFromStorage()
            }
        }
    }

    // MARK: - Sections

    // ── 0. Appearance ─────────────────────────────────────────────────────────
    private var appearanceSection: some View {
        Section(header: Text("Appearance"), footer: Text("Choose your interface appearance. Defaults to Light mode.")) {
            Picker("Theme", selection: $appAppearance) {
                Label("Light", systemImage: "sun.max.fill")
                    .tag("light")
                Label("Dark", systemImage: "moon.fill")
                    .tag("dark")
                Label("System", systemImage: "circle.lefthalf.filled")
                    .tag("system")
            }
            .pickerStyle(.segmented)
            .padding(.vertical, 4)
        }
    }

    // ── 0.5 Real-Time Cloud Sync (iPhone & iPad) ──────────────────────────────
    private var cloudSyncSection: some View {
        Section(
            header: Text("Real-Time Cloud Sync (iPhone & iPad)"),
            footer: Text("Keep your finances in real-time sync across iPhone and iPad using a free Supabase database. Run supabase_schema.sql once in Supabase SQL Editor.")
        ) {
            HStack {
                Label("Status", systemImage: syncEngine.status.iconName)
                Spacer()
                Text(syncEngine.status.displayText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Project URL")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("https://xyz.supabase.co", text: $supabaseUrlInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .font(.subheadline)
                    .onChange(of: supabaseUrlInput) { _, newValue in
                        syncEngine.supabaseURL = newValue
                    }
            }
            .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text("Anon Public Key")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SecureField("eyJhbGciOi...", text: $supabaseKeyInput)
                    .font(.subheadline)
                    .onChange(of: supabaseKeyInput) { _, newValue in
                        syncEngine.supabaseAnonKey = newValue
                    }
            }
            .padding(.vertical, 2)

            if AppSecrets.isSupabaseConfiguredLocally {
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Text("Auto-configured via Secrets.local.plist")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }

            Button {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                Task {
                    await syncEngine.syncAll(context: modelContext)
                }
            } label: {
                HStack {
                    Spacer()
                    if syncEngine.isSyncing {
                        ProgressView()
                            .padding(.trailing, 6)
                        Text("Syncing with Cloud...")
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Sync Now")
                    }
                    Spacer()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(syncEngine.isConfigured ? Color.primary : Color.secondary)
            }
            .disabled(!syncEngine.isConfigured || syncEngine.isSyncing)

            Button {
                showSyncSetupSheet = true
            } label: {
                Label("How to Setup Free Database", systemImage: "questionmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
        }
    }

    private func stepRow(number: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.bold())
                .foregroundStyle(Color(uiColor: .systemBackground))
                .frame(width: 24, height: 24)
                .background(Color.primary)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // ── 1. Ledgers ────────────────────────────────────────────────────────────
    private var ledgerSection: some View {
        Section(header: Text("Ledger")) {
            if let activeLedger = appState.selectedLedger {
                HStack(spacing: 12) {
                    Image(systemName: activeLedger.icon)
                        .foregroundStyle(.white)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 38, height: 38)
                        .background(Color(hex: activeLedger.colorHex))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(activeLedger.name)
                                .font(.headline)
                            if activeLedger.isDefault {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.yellow)
                            }
                        }
                        Text("Active • \(activeLedger.currency)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(activeLedger.balance.currencyString(code: activeLedger.currency))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(activeLedger.balance >= 0 ? Color(.systemGreen) : Color(.systemRed))
                }
                .padding(.vertical, 4)
            }

            NavigationLink {
                LedgerListView(isEmbedded: true)
            } label: {
                HStack {
                    Label("Manage All Ledgers", systemImage: "square.stack.3d.up")
                    Spacer()
                    Text("\(ledgers.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("manageLedgersNavLink")
        }
    }

    // ── Accounts & Net Worth ──────────────────────────────────────────────────
    private var accountsSection: some View {
        Section(header: Text("Accounts & Net Worth")) {
            NavigationLink {
                AccountsHubView()
            } label: {
                HStack {
                    Label("Bank Accounts", systemImage: "building.columns.fill")
                    Spacer()
                    Text("\(accounts.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // ── 2. Organize ───────────────────────────────────────────────────────────
    private var organizeSection: some View {
        Section(header: Text("Organize")) {
            NavigationLink {
                CategoryListView(isEmbedded: true)
            } label: {
                HStack {
                    Label("Categories", systemImage: "folder.fill")
                    Spacer()
                    Text("\(categories.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("categoriesNavLink")

            NavigationLink {
                TagListView(isEmbedded: true)
            } label: {
                HStack {
                    Label("Tags", systemImage: "tag.fill")
                    Spacer()
                    Text("\(tags.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("tagsNavLink")

            NavigationLink {
                RecurringListView(isEmbedded: true)
            } label: {
                HStack {
                    Label("Recurring Rules", systemImage: "arrow.triangle.2.circlepath")
                    Spacer()
                    Text("\(recurringRules.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("recurringRulesNavLink")
        }
    }

    // ── 3. Notifications ──────────────────────────────────────────────────────
    private var notificationsSection: some View {
        Section(header: Text("Notifications"), footer: Text("Daily local notifications keep your budget tracking on schedule without requiring internet access.")) {
            Toggle("Daily Reminder", isOn: $dailyReminderEnabled)
                .onChange(of: dailyReminderEnabled) { _, isEnabled in
                    handleDailyReminderToggle(isEnabled: isEnabled)
                }
                .accessibilityIdentifier("dailyReminderToggle")

            if dailyReminderEnabled {
                DatePicker(
                    "Reminder Time",
                    selection: $reminderDate,
                    displayedComponents: .hourAndMinute
                )
                .onChange(of: reminderDate) { _, newDate in
                    handleReminderTimeChange(newDate: newDate)
                }
                .accessibilityIdentifier("reminderTimePicker")
            }
        }
    }

    // ── 3.5 Gemini AI ────────────────────────────────────────────────────────
    private var geminiSection: some View {
        Section(header: Text("Gemini AI Receipt Scanner"), footer: Text("Multimodal AI receipt scanning powered by Google Gemini 3.5 Flash Lite is pre-configured and active.")) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.primary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Gemini 3.5 Flash Lite")
                        .font(.subheadline.weight(.semibold))
                    Text("Multimodal Receipt Recognition")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.primary)
                        .frame(width: 6, height: 6)
                    Text("Active")
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.08))
                .clipShape(Capsule())
            }
            .padding(.vertical, 3)
        }
    }

    // ── 3.6 Back Tap Bookkeeping ──────────────────────────────────────────────
    @State private var showCopiedAlert = false

    private var backTapSection: some View {
        Section(header: Text("Back Tap Quick Bookkeeping"), footer: Text("Double-tap or triple-tap the back of your iPhone on any receipt or payment screen to automatically analyze and log the transaction.")) {
            HStack(spacing: 12) {
                Image(systemName: "hand.tap.fill")
                    .foregroundStyle(.primary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Back Tap Bookkeeping")
                        .font(.subheadline.weight(.semibold))
                    Text("1-Tap AI Screenshot Recognition")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 2)

            Button {
                appState.showBackTapScanner = true
            } label: {
                Label("Test Back Tap Scanner Now", systemImage: "play.circle.fill")
                    .foregroundStyle(.primary)
                    .font(.subheadline.weight(.medium))
            }

            Button {
                UIPasteboard.general.string = "financetracker://backtap"
                showCopiedAlert = true
            } label: {
                HStack {
                    Label("Copy URL Scheme", systemImage: "doc.on.clipboard")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("financetracker://backtap")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            DisclosureGroup {
                VStack(alignment: .leading, spacing: 10) {
                    Text("3-Step Setup Guide:")
                        .font(.subheadline.weight(.semibold))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("1. Open the Apple Shortcuts app and tap + to create a new shortcut.")
                        Text("2. Add 3 actions in sequence:")
                        VStack(alignment: .leading, spacing: 4) {
                            Text("   • Take Screenshot")
                            Text("   • Copy to Clipboard")
                            Text("   • Open URLs ➔ paste: financetracker://backtap")
                        }
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        Text("3. Go to iPhone Settings ➔ Accessibility ➔ Touch ➔ Back Tap ➔ Choose Double Tap / Triple Tap ➔ Select your Shortcut.")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } label: {
                Label("How to Configure iOS Back Tap", systemImage: "questionmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
        }
    }

    // ── 4. Data & Backup ──────────────────────────────────────────────────────
    private var dataSection: some View {
        Section(header: Text("Data & Currency"), footer: Text("Manage your currency format or backup transactions in RFC 4180 CSV format.")) {
            if let ledger = appState.selectedLedger, ledger.currency != "MYR" {
                Button {
                    showMigrateMYRAlert = true
                } label: {
                    Label("Switch Active Ledger to MYR (RM)", systemImage: "coloncurrencysign.circle")
                }
            }

            if let url = exportTempURL {
                ShareLink(item: url) {
                    Label("Export Transactions (CSV)", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("exportCSVButton")
            }

            Button {
                showFileImporter = true
            } label: {
                Label("Import Transactions (CSV)", systemImage: "square.and.arrow.down")
            }
            .accessibilityIdentifier("importCSVButton")

            Button(role: .destructive) {
                showResetAlert = true
            } label: {
                Label("Reset to Fresh Sample Data (MYR)", systemImage: "arrow.counterclockwise")
            }
        }
    }

    // ── 5. About ──────────────────────────────────────────────────────────────
    private var aboutSection: some View {
        Section(header: Text("About")) {
            HStack {
                Text("App Version")
                Spacer()
                Text(appVersionString)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Storage")
                Spacer()
                Text("SwiftData (Local Only)")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Deployment")
                Spacer()
                Text("Personal Sideload")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Notification Handlers

    private func syncReminderDateFromStorage() {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        comps.hour = dailyReminderHour
        comps.minute = dailyReminderMinute
        if let date = Calendar.current.date(from: comps) {
            reminderDate = date
        }
    }

    private func handleDailyReminderToggle(isEnabled: Bool) {
        if isEnabled {
            Task {
                await NotificationService.requestAuthorisation()
                let hour = Calendar.current.component(.hour, from: reminderDate)
                let minute = Calendar.current.component(.minute, from: reminderDate)
                dailyReminderHour = hour
                dailyReminderMinute = minute
                NotificationService.scheduleDailyReminder(at: hour, minute: minute)
            }
        } else {
            NotificationService.cancelDailyReminder()
        }
    }

    private func handleReminderTimeChange(newDate: Date) {
        let hour = Calendar.current.component(.hour, from: newDate)
        let minute = Calendar.current.component(.minute, from: newDate)
        dailyReminderHour = hour
        dailyReminderMinute = minute
        if dailyReminderEnabled {
            NotificationService.scheduleDailyReminder(at: hour, minute: minute)
        }
    }

    // MARK: - CSV Import Handler

    private func handleCSVImport(result: Result<[URL], Error>) {
        do {
            guard let selectedURL = try result.get().first else { return }

            guard selectedURL.startAccessingSecurityScopedResource() else {
                importAlertTitle = "Access Denied"
                importAlertMessage = "Could not access the selected file."
                showImportAlert = true
                return
            }
            defer { selectedURL.stopAccessingSecurityScopedResource() }

            let csvString = try String(contentsOf: selectedURL, encoding: .utf8)
            guard let ledger = appState.selectedLedger else {
                importAlertTitle = "No Ledger Selected"
                importAlertMessage = "Please select an active ledger before importing."
                showImportAlert = true
                return
            }

            let outcome = CSVService.importCSV(from: csvString, ledger: ledger, context: modelContext)

            importAlertTitle = outcome.imported > 0 ? "Import Complete" : "Import Failed"
            var message = "Imported \(outcome.imported) transaction(s) into '\(ledger.name)'."
            if !outcome.errors.isEmpty {
                message += "\n\nIssues encountered (\(outcome.errors.count)):\n" + outcome.errors.prefix(5).joined(separator: "\n")
            }
            importAlertMessage = message
            showImportAlert = true
        } catch {
            importAlertTitle = "Import Error"
            importAlertMessage = error.localizedDescription
            showImportAlert = true
        }
    }

    // MARK: - App Version

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.9.1"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "22"
        return "v\(version) (Build \(build))"
    }
}
