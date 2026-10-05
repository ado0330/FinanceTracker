import SwiftUI
import SwiftData

@main
struct FinanceTrackerApp: App {

    // MARK: - SwiftData Container

    private let container: ModelContainer

    // MARK: - Shared State

    @State private var appState = AppState()

    // MARK: - Init

    init() {
        let schema = Schema([
            Ledger.self,
            Transaction.self,
            Category.self,
            Tag.self,
            Budget.self,
            RecurringRule.self,
            SplitMember.self,
            SplitExpense.self,
            SplitSettlement.self,
            SplitGroup.self,
            Account.self,
        ])

        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            print("⚠️ SwiftData ModelContainer migration issue: \(error.localizedDescription). Attempting recovery...")
            // If the local store failed migration due to schema change from an earlier build,
            // remove incompatible store files so the app can recreate the database cleanly.
            if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let fileManager = FileManager.default
                if let files = try? fileManager.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil) {
                    for file in files where file.lastPathComponent.contains(".store") {
                        try? fileManager.removeItem(at: file)
                    }
                }
            }

            do {
                container = try ModelContainer(for: schema, configurations: config)
            } catch {
                print("⚠️ Persistent store recovery failed: \(error.localizedDescription). Falling back to in-memory container.")
                let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                container = (try? ModelContainer(for: schema, configurations: memoryConfig)) ?? {
                    fatalError("❌ SwiftData ModelContainer failed to initialize: \(error.localizedDescription)")
                }()
            }
        }
    }

    // MARK: - Appearance Preference (defaults to "light")

    @AppStorage("appAppearance") private var appAppearance: String = "light"

    private var currentColorScheme: ColorScheme? {
        switch appAppearance {
        case "light": return .light
        case "dark": return .dark
        case "system": return nil
        default: return .light
        }
    }

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)   // Injects ModelContext into the environment
                .environment(appState)        // Injects AppState into the environment
                .preferredColorScheme(currentColorScheme)
                .tint(.primary)
                .task {
                    // Request notification permission on first launch.
                    // This is idempotent — repeated calls are no-ops after first decision.
                    await NotificationService.requestAuthorisation()
                }
        }
    }
}
