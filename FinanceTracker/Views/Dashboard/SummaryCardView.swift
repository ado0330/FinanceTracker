import SwiftUI

/// A reusable metric card used on the Dashboard.
///
/// Shows a coloured icon, a label, and a prominent currency amount.
/// Optionally shows a subtitle (e.g. "this month") and a percentage change badge.
struct SummaryCardView: View {

    // MARK: - Input
    let title: String
    let amount: Double
    let currencyCode: String
    let icon: String
    let tintColor: Color

    /// Optional secondary line below the title, e.g. "This month".
    var subtitle: String? = nil

    /// Optional percentage change vs the previous period.
    /// Positive = up (green), negative = down (red), nil = hidden.
    var percentChange: Double? = nil

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // ── Header row ─────────────────────────────────────────────
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tintColor)
                    .frame(width: 28, height: 28)
                    .background(tintColor.opacity(0.15))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.4)

                    if let sub = subtitle {
                        Text(sub)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                // Percentage badge
                if let pct = percentChange {
                    percentBadge(pct)
                }
            }

            // ── Amount ─────────────────────────────────────────────────
            Text(amount.currencyString(code: currencyCode))
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Percent badge

    private func percentBadge(_ pct: Double) -> some View {
        let isPositive = pct >= 0
        let badgeColor: Color = isPositive ? .green : .red
        let arrow = isPositive ? "arrow.up.right" : "arrow.down.right"
        let label = "\(isPositive ? "+" : "")\(Int(pct.rounded()))%"

        return HStack(spacing: 3) {
            Image(systemName: arrow)
                .font(.caption2.weight(.bold))
            Text(label)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(badgeColor)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(badgeColor.opacity(0.12), in: Capsule())
    }
}
