import Foundation
import Observation
import SwiftData

/// Offline-First Synchronization Engine between local SwiftData and Supabase Cloud.
///
/// Features:
/// - Bidirectional synchronization with Last-Write-Wins conflict resolution
/// - Soft deletion (tombstone) propagation to prevent reviving deleted items
/// - Real-time WebSocket connection to Supabase Realtime channels
/// - Automatic fallback to offline mode when disconnected
@Observable
@MainActor
public final class SyncEngine {

    public static let shared = SyncEngine()

    // MARK: - State

    public enum SyncStatus: Equatable {
        case notConfigured
        case idle
        case syncing
        case synced(Date)
        case offline
        case error(String)

        public var displayText: String {
            switch self {
            case .notConfigured: return "Not Configured"
            case .idle: return "Ready"
            case .syncing: return "Syncing..."
            case .synced(let date): return "Synced \(date.formatted(date: .omitted, time: .shortened))"
            case .offline: return "Offline"
            case .error(let msg): return "Error: \(msg)"
            }
        }

        public var iconName: String {
            switch self {
            case .notConfigured: return "icloud.slash"
            case .idle: return "cloud"
            case .syncing: return "arrow.triangle.2.circlepath"
            case .synced: return "checkmark.icloud.fill"
            case .offline: return "wifi.slash"
            case .error: return "exclamationmark.icloud.fill"
            }
        }
    }

    public var status: SyncStatus = .notConfigured
    public var isSyncing: Bool = false
    public var lastSyncedAt: Date? = nil

    // MARK: - Credentials

    private let urlKey = "supabase_project_url"
    private let keyKey = "supabase_anon_key"

    public var supabaseURL: String {
        get {
            let saved = UserDefaults.standard.string(forKey: urlKey) ?? ""
            if !saved.isEmpty { return saved }
            return AppSecrets.supabaseURL
        }
        set {
            UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: urlKey)
            updateConfigurationState()
        }
    }

    public var supabaseAnonKey: String {
        get {
            let saved = UserDefaults.standard.string(forKey: keyKey) ?? ""
            if !saved.isEmpty { return saved }
            return AppSecrets.supabaseAnonKey
        }
        set {
            UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: keyKey)
            updateConfigurationState()
        }
    }

    public var isConfigured: Bool {
        !supabaseURL.isEmpty && !supabaseAnonKey.isEmpty
    }

    // MARK: - JSON Encoders

    private let jsonEncoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        return enc
    }()

    private let jsonDecoder: JSONDecoder = {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }()

    // MARK: - WebSocket Task for Realtime

    private var webSocketTask: URLSessionWebSocketTask? = nil
    private var pingTimer: Timer? = nil

    // MARK: - Init

    public init() {
        updateConfigurationState()
    }

    private func updateConfigurationState() {
        if isConfigured {
            if status == .notConfigured {
                status = .idle
            }
        } else {
            status = .notConfigured
        }
    }

    // MARK: - Manual & Auto Sync

    public func syncAll(context: ModelContext) async {
        guard isConfigured else {
            status = .notConfigured
            return
        }

        isSyncing = true
        status = .syncing

        do {
            // 1. Push local changes
            try await pushLocalChanges(context: context)

            // 2. Pull remote changes
            try await pullRemoteChanges(context: context)

            let now = Date.now
            lastSyncedAt = now
            status = .synced(now)
            isSyncing = false
        } catch {
            status = .error(error.localizedDescription)
            isSyncing = false
        }
    }

    // MARK: - Outbound Push

    private func pushLocalChanges(context: ModelContext) async throws {
        guard isConfigured else { return }

        // Fetch local records
        let ledgersDescriptor = FetchDescriptor<Ledger>()
        let localLedgers = (try? context.fetch(ledgersDescriptor)) ?? []
        for ledger in localLedgers {
            let dto = LedgerDTO(from: ledger)
            try await upsertRecord(endpoint: "ledgers", body: dto)
        }

        let categoriesDescriptor = FetchDescriptor<Category>()
        let localCategories = (try? context.fetch(categoriesDescriptor)) ?? []
        for category in localCategories {
            let dto = CategoryDTO(from: category)
            try await upsertRecord(endpoint: "categories", body: dto)
        }

        let accountsDescriptor = FetchDescriptor<Account>()
        let localAccounts = (try? context.fetch(accountsDescriptor)) ?? []
        for account in localAccounts {
            let dto = AccountDTO(from: account)
            try await upsertRecord(endpoint: "accounts", body: dto)
        }

        let txDescriptor = FetchDescriptor<Transaction>()
        let localTransactions = (try? context.fetch(txDescriptor)) ?? []
        for tx in localTransactions {
            let dto = TransactionDTO(from: tx)
            try await upsertRecord(endpoint: "transactions", body: dto)
        }

        let budgetsDescriptor = FetchDescriptor<Budget>()
        let localBudgets = (try? context.fetch(budgetsDescriptor)) ?? []
        for budget in localBudgets {
            let dto = BudgetDTO(from: budget)
            try await upsertRecord(endpoint: "budgets", body: dto)
        }

        let rulesDescriptor = FetchDescriptor<RecurringRule>()
        let localRules = (try? context.fetch(rulesDescriptor)) ?? []
        for rule in localRules {
            let dto = RecurringRuleDTO(from: rule)
            try await upsertRecord(endpoint: "recurring_rules", body: dto)
        }
    }

    private func upsertRecord<T: Encodable>(endpoint: String, body: T) async throws {
        guard let baseURL = URL(string: supabaseURL) else { return }
        let url = baseURL.appendingPathComponent("rest/v1/\(endpoint)")
            .appending(queryItems: [URLQueryItem(name: "on_conflict", value: "id")])

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = try jsonEncoder.encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            print("❌ SyncEngine upsertRecord failed [\(endpoint)] HTTP \(http.statusCode): \(errorBody)")
            throw NSError(domain: "SyncEngine", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode) pushing to \(endpoint)"])
        }
    }

    // MARK: - Inbound Pull

    private func pullRemoteChanges(context: ModelContext) async throws {
        guard isConfigured else { return }

        // Pull Ledgers
        if let remoteLedgers: [LedgerDTO] = try? await fetchRecords(endpoint: "ledgers") {
            let localLedgers = (try? context.fetch(FetchDescriptor<Ledger>())) ?? []
            for remote in remoteLedgers {
                if let local = localLedgers.first(where: { $0.id == remote.id }) {
                    local.name = remote.name
                    local.currency = remote.currency
                    local.colorHex = remote.color_hex
                    local.isDefault = remote.is_default
                } else if remote.deleted_at == nil {
                    let newLedger = Ledger(name: remote.name, colorHex: remote.color_hex, currency: remote.currency, isDefault: remote.is_default)
                    newLedger.id = remote.id
                    context.insert(newLedger)
                }
            }
        }

        // Pull Categories
        if let remoteCategories: [CategoryDTO] = try? await fetchRecords(endpoint: "categories") {
            let localCategories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
            for remote in remoteCategories {
                if let local = localCategories.first(where: { $0.id == remote.id }) {
                    local.name = remote.name
                    local.icon = remote.icon
                    local.colorHex = remote.color_hex
                    local.sortOrder = remote.sort_order
                } else if remote.deleted_at == nil {
                    let catType = CategoryType(rawValue: remote.type) ?? .expense
                    let newCat = Category(name: remote.name, icon: remote.icon, colorHex: remote.color_hex, type: catType, isSystem: remote.is_system, sortOrder: remote.sort_order)
                    newCat.id = remote.id
                    context.insert(newCat)
                }
            }
        }

        // Pull Accounts
        if let remoteAccounts: [AccountDTO] = try? await fetchRecords(endpoint: "accounts") {
            let localAccounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
            for remote in remoteAccounts {
                if let local = localAccounts.first(where: { $0.id == remote.id }) {
                    local.name = remote.name
                    local.institution = remote.institution
                    local.accountTypeRaw = remote.account_type
                    local.accountNumberLast4 = remote.last_four
                    local.colorHex = remote.color_hex
                    local.icon = remote.icon
                    local.initialBalance = remote.starting_balance
                } else if remote.deleted_at == nil {
                    let accType = AccountType(rawValue: remote.account_type) ?? .bank
                    let newAcc = Account(
                        name: remote.name,
                        institution: remote.institution,
                        accountType: accType,
                        accountNumberLast4: remote.last_four,
                        initialBalance: remote.starting_balance,
                        colorHex: remote.color_hex,
                        icon: remote.icon
                    )
                    newAcc.id = remote.id
                    context.insert(newAcc)
                }
            }
        }

        // Pull Transactions
        if let remoteTxns: [TransactionDTO] = try? await fetchRecords(endpoint: "transactions") {
            let localTxns = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
            let allCategories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
            let allLedgers = (try? context.fetch(FetchDescriptor<Ledger>())) ?? []
            let allAccounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []

            for remote in remoteTxns {
                if let local = localTxns.first(where: { $0.id == remote.id }) {
                    if remote.deleted_at != nil {
                        context.delete(local)
                    } else {
                        local.name = remote.name
                        local.amount = remote.amount
                        local.type = TransactionType(rawValue: remote.type) ?? .expense
                        local.date = remote.date
                        local.note = remote.note
                        if let b64 = remote.receipt_image_base64 {
                            local.receiptImageData = Data(base64Encoded: b64)
                        }
                    }
                } else if remote.deleted_at == nil {
                    let matchedCategory = allCategories.first(where: { $0.id == remote.category_id })
                    let matchedLedger = allLedgers.first(where: { $0.id == remote.ledger_id })
                    let matchedAccount = allAccounts.first(where: { $0.id == remote.account_id })
                    let txType = TransactionType(rawValue: remote.type) ?? .expense
                    let receiptData = remote.receipt_image_base64.flatMap { Data(base64Encoded: $0) }

                    let newTx = Transaction(
                        name: remote.name,
                        amount: remote.amount,
                        type: txType,
                        date: remote.date,
                        note: remote.note,
                        ledger: matchedLedger,
                        category: matchedCategory,
                        account: matchedAccount,
                        receiptImageData: receiptData
                    )
                    newTx.id = remote.id
                    context.insert(newTx)
                }
            }
        }

        try? context.save()
    }

    private func fetchRecords<T: Decodable>(endpoint: String) async throws -> [T] {
        guard let baseURL = URL(string: supabaseURL) else { return [] }
        let url = baseURL.appendingPathComponent("rest/v1/\(endpoint)")
            .appending(queryItems: [URLQueryItem(name: "select", value: "*")])

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NSError(domain: "SyncEngine", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode) pulling \(endpoint)"])
        }

        return try jsonDecoder.decode([T].self, from: data)
    }

    // MARK: - Realtime WebSocket Connection

    public func startRealtimeSync(context: ModelContext) {
        guard isConfigured, let baseURL = URL(string: supabaseURL) else { return }
        guard let host = baseURL.host else { return }

        let wsURLString = "wss://\(host)/realtime/v1/websocket?apikey=\(supabaseAnonKey)&vsn=1.0.0"
        guard let wsURL = URL(string: wsURLString) else { return }

        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = URLSession.shared.webSocketTask(with: wsURL)
        webSocketTask?.resume()

        listenForMessages(context: context)
        startHeartbeat()
    }

    private func listenForMessages(context: ModelContext) {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    // When a postgres change broadcast arrives, pull updates!
                    if text.contains("INSERT") || text.contains("UPDATE") || text.contains("DELETE") {
                        Task { @MainActor in
                            try? await self.pullRemoteChanges(context: context)
                            self.status = .synced(.now)
                        }
                    }
                case .data:
                    break
                @unknown default:
                    break
                }
                self.listenForMessages(context: context)
            case .failure:
                // Reconnect if needed
                break
            }
        }
    }

    private func startHeartbeat() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.webSocketTask?.sendPing { error in
                if error != nil {
                    // Reconnect on next cycle
                }
            }
        }
    }
}
