import SwiftUI
import SwiftData

/// Rich preview card presented when a user long-presses (haptic touch / context menu)
/// on any transaction row in the ledger or dashboard.
///
/// Features:
/// - Large, high-resolution food / receipt photo display
/// - Transaction name, amount, category, account, and date
/// - Prominent review & note card showcasing user evaluations
struct TransactionPreviewCard: View {

    let transaction: Transaction

    private var currencyCode: String {
        transaction.ledger?.currency ?? "MYR"
    }

    private var amountString: String {
        let raw = transaction.amount
        let formatted = raw.currencyString(code: currencyCode)
        return transaction.type == .income ? "+\(formatted)" : formatted
    }

    private var amountColor: Color {
        transaction.type == .income ? Color(.systemGreen) : Color(.label)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Photo / Receipt Image (if present) ──────────────────────────
            if let data = transaction.receiptImageData, let uiImage = UIImage(data: data) {
                ZStack(alignment: .bottomTrailing) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 240)
                        .clipped()

                    // Photo badge
                    HStack(spacing: 4) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("Photo Attached")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(10)
                }
            }

            // ── Header & Amount ─────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(transaction.displayName)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        HStack(spacing: 6) {
                            if let cat = transaction.category {
                                HStack(spacing: 4) {
                                    Image(systemName: cat.icon)
                                        .font(.system(size: 10))
                                    Text(cat.name)
                                        .font(.caption.weight(.medium))
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: cat.colorHex).opacity(0.15))
                                .foregroundStyle(Color(hex: cat.colorHex))
                                .clipShape(Capsule())
                            }

                            if let acc = transaction.account {
                                Text(acc.name)
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(.tertiarySystemFill))
                                    .clipShape(Capsule())
                                    .foregroundStyle(.secondary)
                            }

                            Text(transaction.date.shortDisplay)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Text(amountString)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(amountColor)
                }

                // ── Note / Food Review Section ───────────────────────────────
                let trimmedNote = transaction.note.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedNote.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "quote.opening")
                                .font(.caption2.weight(.bold))
                            Text("Note & Review")
                                .font(.caption2.weight(.bold))
                                .textCase(.uppercase)
                                .tracking(0.6)
                        }
                        .foregroundStyle(.secondary)

                        Text(trimmedNote)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else if transaction.receiptImageData == nil {
                    Text("No review or photo attached.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                }

                // ── Tags (if any) ───────────────────────────────────────────
                if !transaction.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(transaction.tags) { tag in
                                Text("#\(tag.name)")
                                    .font(.caption2.weight(.medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.primary.opacity(0.06))
                                    .clipShape(Capsule())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .frame(width: 320)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }
}
