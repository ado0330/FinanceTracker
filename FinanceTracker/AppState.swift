import Foundation
import Observation
import UIKit

/// Central, observable state shared across the entire app via SwiftUI's environment.
/// Holds the active ledger selection and the current tab — both needed by multiple views.
@Observable
final class AppState {

    // MARK: - Ledger Context

    /// The ledger currently in focus. All transactions, budgets, and charts
    /// filter to this ledger. Set on launch to the `isDefault` ledger.
    var selectedLedger: Ledger? = nil

    // MARK: - Splitter Group Context

    /// The active split group currently in focus (e.g. "Penang Trip", "Roommates").
    var selectedSplitGroup: SplitGroup? = nil

    // MARK: - Navigation

    var selectedTab: AppTab = .dashboard

    // MARK: - Back Tap Quick Scan State

    /// Set to true when triggered via URL scheme (e.g. `financetracker://backtap`) or quick scan button.
    var showBackTapScanner: Bool = false

    /// Optional pre-loaded image (e.g. from clipboard or testing) to pass directly into BackTapQuickScanView.
    var backTapInitialImage: UIImage? = nil

    // MARK: - Accounts & Net Worth State

    /// Set to true to present the full Accounts & Net Worth hub.
    var showAccountsHub: Bool = false

    // MARK: - Global Action Sheets

    /// Set to true to present the Add New Transaction sheet directly (e.g. from Cmd+N or quick action).
    var showAddTransactionSheet: Bool = false

    enum AppTab: Int, Hashable {
        case dashboard
        case transactions
        case charts
        case splitter
        case budgets
        case settings
    }
}
