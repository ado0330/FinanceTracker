import SwiftUI
import SwiftData

/// Discreet, luxury monochrome sync status badge for toolbars.
///
/// States:
/// - Synced (cloud checkmark)
/// - Syncing (rotating arrows)
/// - Not Configured / Offline (cloud with slash)
/// - Tap to trigger instant manual sync
public struct SyncStatusBadge: View {

    @Environment(\.modelContext) private var modelContext
    @State private var syncEngine = SyncEngine.shared
    @State private var isSpinning: Bool = false

    public init() {}

    public var body: some View {
        Button {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            Task {
                await syncEngine.syncAll(context: modelContext)
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: syncEngine.status.iconName)
                    .font(.caption2.bold())
                    .rotationEffect(.degrees(syncEngine.isSyncing ? 360 : 0))
                    .animation(syncEngine.isSyncing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: syncEngine.isSyncing)

                Text(badgeText)
                    .font(.caption2.weight(.medium))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.06))
            .foregroundStyle(.primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("syncStatusBadge")
    }

    private var badgeText: String {
        switch syncEngine.status {
        case .notConfigured:
            return "Sync Off"
        case .idle:
            return "Ready"
        case .syncing:
            return "Syncing"
        case .synced:
            return "Synced"
        case .offline:
            return "Offline"
        case .error:
            return "Sync Retry"
        }
    }
}
