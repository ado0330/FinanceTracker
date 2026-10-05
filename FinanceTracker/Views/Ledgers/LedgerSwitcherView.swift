import SwiftUI
import SwiftData

/// A compact, pill-shaped menu in the navigation bar for switching the active ledger.
///
/// Displays the current ledger's icon + name. Tapping shows a menu of all ledgers;
/// selecting one updates `AppState.selectedLedger` app-wide.
///
/// Usage:
/// ```swift
/// .toolbar {
///     ToolbarItem(placement: .principal) {
///         LedgerSwitcherView()
///     }
/// }
/// ```
struct LedgerSwitcherView: View {

    // MARK: - Environment
    @Environment(AppState.self) private var appState

    @Query(sort: \Ledger.createdAt) private var ledgers: [Ledger]

    // MARK: - Body
    var body: some View {
        Menu {
            ForEach(ledgers) { ledger in
                Button {
                    appState.selectedLedger = ledger
                } label: {
                    HStack {
                        Label(ledger.name, systemImage: ledger.icon)
                        if appState.selectedLedger?.id == ledger.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .accessibilityIdentifier("switchLedger_\(ledger.id)")
            }

            Divider()

            // Shortcut to the full ledger management screen (Tab 5 → Settings
            // houses it; wired in SettingsView at T-21).
            // For now we navigate programmatically via AppState.
            Button {
                appState.selectedTab = .settings
            } label: {
                Label("Manage Ledgers…", systemImage: "square.stack.3d.up")
            }
            .accessibilityIdentifier("manageLedgersButton")

        } label: {
            pillLabel
        }
        .accessibilityIdentifier("ledgerSwitcherMenu")
    }

    // MARK: - Pill label

    private var pillLabel: some View {
        HStack(spacing: 6) {
            if let ledger = appState.selectedLedger {
                Image(systemName: ledger.icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Color(hex: ledger.colorHex))
                    .clipShape(Circle())

                Text(ledger.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            } else {
                Image(systemName: "creditcard.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("No Ledger")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.down")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .contentShape(Capsule())
    }
}
