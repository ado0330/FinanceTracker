import SwiftUI
import SwiftData

/// A single row in the transaction list.
///
/// Shows:
///   - Category colour + icon badge
///   - Transaction title (category name or note fallback) + optional receipt attachment indicator
///   - Subtitle: formatted date + optional note preview
///   - Amount with sign-coloured currency string
struct TransactionRowView: View {

    let transaction: Transaction
    var showDate: Bool = true

    // Currency code is derived from the parent ledger.
    var currencyCode: String { transaction.ledger?.currency ?? "MYR" }

    var body: some View {
        HStack(spacing: 12) {

            // ── Icon badge ─────────────────────────────────────────────────
            iconBadge

            // ── Labels ─────────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(primaryLabel)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .accessibilityIdentifier("txnTitle_\(transaction.id)")

                    if transaction.receiptImageData != nil {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }

                    if !transaction.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                        transaction.note.trimmingCharacters(in: .whitespacesAndNewlines) != (transaction.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines) {
                        Image(systemName: "text.bubble.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }

                if !secondaryLabel.isEmpty || transaction.account != nil {
                    HStack(spacing: 4) {
                        if !secondaryLabel.isEmpty {
                            Text(secondaryLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .accessibilityIdentifier("txnSubtitle_\(transaction.id)")
                        }

                        if let acc = transaction.account {
                            if !secondaryLabel.isEmpty {
                                Text("·")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text(acc.name)
                                .font(.system(size: 10, weight: .medium))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color(.tertiarySystemFill))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            // ── Amount ─────────────────────────────────────────────────────
            Text(amountString)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(amountColor)
                .accessibilityIdentifier("txnAmount_\(transaction.id)")
        }
        .padding(.vertical, 4)
    }

    // MARK: - Computed helpers

    private var iconBadge: some View {
        let color: Color = transaction.category.map { Color(hex: $0.colorHex) } ?? .gray
        let icon: String = transaction.category?.icon ?? "questionmark"
        return Image(systemName: icon)
            .foregroundStyle(.white)
            .font(.system(size: 14, weight: .semibold))
            .frame(width: 36, height: 36)
            .background(color)
            .clipShape(Circle())
            .accessibilityIdentifier("txnIcon_\(transaction.id)")
    }

    private var primaryLabel: String {
        transaction.displayName
    }

    private var secondaryLabel: String {
        let catName = transaction.category?.name ?? "Uncategorised"
        if showDate {
            let dateStr = transaction.date.shortDisplay         // from Date+Helpers
            return "\(dateStr)  ·  \(catName)"
        } else {
            return catName
        }
    }

    private var amountString: String {
        let raw = transaction.amount
        let formatted = raw.currencyString(code: currencyCode)  // from Double+Currency
        return transaction.type == .income ? "+\(formatted)" : formatted
    }

    private var amountColor: Color {
        transaction.type == .income ? Color(.systemGreen) : Color(.label)
    }
}
